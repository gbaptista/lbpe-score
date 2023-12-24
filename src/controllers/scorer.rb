# frozen_string_literal: true

require 'digest'

require_relative '../logic/printer'
require_relative '../components/environment'

module LBPE
  module Controllers
    module Scorer
      def self.handle!(benchmark)
        models = Dir['cartridges/models/*/*/*.yml'].map do |path|
          path.sub('cartridges/models/', '').sub('.yml', '')
        end

        benchmarks = if benchmark == 'MMLU'
                       Dir['data/datasets/MMLU-*'].map do |path|
                         path.split('/').last
                       end
                     elsif benchmark
                       [benchmark]
                     else
                       Dir['data/datasets/*'].map do |path|
                         path.split('/').last
                       end
                     end

        benchmarks.each do |benchmark|
          samples = Dir["data/datasets/#{benchmark}/*.yml"].map(&:to_s)

          samples.each do |sample|
            models.each do |model|
              score_model(benchmark, model, sample)
            end
          end
        end
      end

      def self.score_model(benchmark, model, sample_path)
        cartridge_path = "cartridges/models/#{model}.yml"

        raw_cartridge = File.read(cartridge_path)

        cartridge = Logic::Printer.symbolize_keys(
          YAML.safe_load(raw_cartridge, permitted_classes: [Symbol])
        )

        score_sample(benchmark, model, cartridge, raw_cartridge, cartridge_path, sample_path)
      end

      def self.score_mmlu_sample(score_path, file, evaluation_id, benchmark, model, at, evaluation, sample)
        score_number = if evaluation[:result].last[:content].strip.upcase == sample[:sample][:'expected-answer'].strip.upcase
                         5
                       else
                         1
                       end

        if evaluation[:result].last[:content].strip.upcase.size != 1 || sample[:sample][:'expected-answer'].strip.upcase.size != 1
          require 'pry'
          binding.pry
        end

        score = {
          analysis: "#{evaluation[:result].last[:content].strip.upcase} == #{sample[:sample][:'expected-answer'].strip.upcase}",
          score: score_number
        }

        data = {
          meta: {
            id: evaluation_id,
            benchmark: benchmark,
            model: model,
            'generated-at': at.iso8601
          },
          environment: Components::Environment.details,
          score: score,
          evaluation: evaluation[:result]
        }

        yaml_data = YAML.dump(Logic::Printer.stringify_keys(data))

        puts "\n> #{score_path}/#{file}"

        FileUtils.mkdir_p(score_path)
        File.write("#{score_path}/#{file}", yaml_data)
      end

      def self.score_sample(benchmark, model, _cartridge, raw_cartridge, _cartridge_path, sample_path)
        raw_sample = File.read(sample_path)

        evaluation_id = Digest::SHA256.hexdigest("#{raw_cartridge}\n#{raw_sample}")

        path = "data/evaluations/#{benchmark}/#{model}"
        file = "#{evaluation_id}.yml"

        unless File.exist?("#{path}/#{file}")
          puts "Sample '#{evaluation_id}' not evaluated yet for '#{model}'."
          return
        end

        score_path = "data/scores/#{benchmark}/#{model}"

        if File.exist?("#{score_path}/#{file}")
          puts "Sample '#{evaluation_id}' already scored for '#{model}'."
          return
        end

        at = Time.now

        evaluation = Logic::Printer.symbolize_keys(
          YAML.safe_load(
            File.read("#{path}/#{file}"), permitted_classes: [Symbol]
          )
        )

        Logic::Printer.symbolize_keys(
          YAML.safe_load(
            raw_sample, permitted_classes: [Symbol]
          )
        )

        puts "\n# #{benchmark}@#{model}"

        bot = if benchmark.start_with?('MMLU')
                NanoBot.new(cartridge: 'cartridges/benchmarks/MMLU/scorer.yml')
              else
                NanoBot.new(cartridge: "cartridges/benchmarks/#{benchmark}/scorer.yml")
              end

        # return score_mmlu_sample(
        #   score_path, file,
        #   evaluation_id, benchmark, model, at,
        #   evaluation, sample
        # )

        input = if benchmark.start_with?('MMLU')
                  evaluation[:result]
                  "The expected correct answer option for this question is: #{evaluation[:sample][:'expected-answer']})\nBased on that, please analyze and score the following evaluation:\n```json\n#{JSON.pretty_generate(
                    evaluation[:result], indent: '  '
                  )}\n```"
                else
                  JSON.pretty_generate(evaluation[:result], indent: '  ')
                end

        score = bot.eval(input) do |_content, fragment, _finished, _meta|
          print fragment unless fragment.nil?
        end

        data = {
          meta: {
            id: evaluation_id,
            benchmark: benchmark,
            model: model,
            'generated-at': at.iso8601
          },
          environment: Components::Environment.details,
          score: JSON.parse(score),
          evaluation: evaluation[:result]
        }

        yaml_data = YAML.dump(Logic::Printer.stringify_keys(data))

        puts "\n> #{score_path}/#{file}"

        FileUtils.mkdir_p(score_path)
        File.write("#{score_path}/#{file}", yaml_data)
      end
    end
  end
end
