# frozen_string_literal: true

require_relative '../logic/printer'

module LBPE
  module Controllers
    module Reporter
      def self.handle!
        results = generate_report

        results.each do |key, model_scores|
          model_scores.each do |model, scores|
            total = scores.values.sum
            difference = (key == 'MMLU' ? 1_760 : 100) - total
            model_scores[model] = { 0 => difference }.merge(scores)
          end
        end

        consolidated = Hash.new { |hash, key| hash[key] = Hash.new(0) }

        results.each_value do |model_scores|
          model_scores.each do |model, scores|
            scores.each do |score, value|
              consolidated[model][score] += value
            end
          end
        end

        results['consolidated'] = consolidated

        percentage = {}

        results.each do |benchmark, model_scores|
          model_scores.each do |model, scores|
            percentage[benchmark] = Hash.new { |hash, key| hash[key] = Hash.new(0) } unless percentage.key?(benchmark)
            scores.each do |score, value|
              if score >= 4
                percentage[benchmark][model][:success] += value
              else
                percentage[benchmark][model][:failure] += value
              end
            end
          end

          model_scores.each_key do |model|
            percentage[benchmark][model][:percentage] = (
              percentage[benchmark][model][:success].to_f /
              (percentage[benchmark][model][:success].to_f + percentage[benchmark][model][:failure].to_f)
            )
          end
        end

        results['percentage'] = percentage

        File.write(
          'site/data/report.json',
          JSON.pretty_generate(results, indent: '  ')
        )

        puts Logic::Printer.pretty(results, as: 'yaml')
      end

      def self.details(benchmark, model)
        results = generate_report
        details = generate_report(details: true)

        scores = results[benchmark][model]
        detail = details[benchmark][model]

        puts Logic::Printer.pretty(scores, as: 'yaml')

        detail[1].slice(0, 5).each do |sample|
          puts '-' * 20
          puts Logic::Printer.pretty(sample[:evaluation], as: 'yaml')
          puts '-' * 20
        end

        detail[5].slice(0, 5).each do |sample|
          puts '-' * 20
          puts Logic::Printer.pretty(sample[:evaluation], as: 'yaml')
          puts '-' * 20
        end
      end

      def self.generate_report(details: false)
        results = {}

        Dir['data/scores/*/*/*/*/*.yml'].map do |path|
          result = Logic::Printer.symbolize_keys(
            YAML.safe_load(File.read(path), permitted_classes: [Symbol])
          )

          benchmark = result[:meta][:benchmark].start_with?('MMLU') ? 'MMLU' : result[:meta][:benchmark]
          model = result[:meta][:model]
          score = result[:score][:score]

          model = model.split('/').last(2).join('/')

          results[benchmark] = {} unless results.key?(benchmark)

          unless results[benchmark].key?(model)
            results[benchmark][model] = if details
                                          {
                                            1 => [], 2 => [], 3 => [], 4 => [], 5 => []
                                          }
                                        else
                                          {
                                            1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0
                                          }
                                        end
          end

          if details
            results[benchmark][model][score] << result
          else
            results[benchmark][model][score] += 1
          end
        rescue StandardError => e
          puts path
          puts e.message
        end

        results
      end
    end
  end
end
