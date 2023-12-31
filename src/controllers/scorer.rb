# frozen_string_literal: true

require 'digest'

require_relative '../logic/printer'
require_relative '../logic/identifier'
require_relative '../components/environment'

module LBPE
  module Controllers
    module Scorer
      def self.handle!(benchmark)
        models = Dir['cartridges/models/*/*/*.yml'].shuffle.map do |path|
          path.sub('cartridges/models/', '').sub('.yml', '')
        end

        benchmarks = if benchmark == 'MMLU'
                       Dir['data/datasets/MMLU-*'].map do |path|
                         path.split('/').last
                       end
                     elsif benchmark == 'ENEM'
                       Dir['data/datasets/ENEM-*'].map do |path|
                         path.split('/').last
                       end
                     elsif benchmark
                       [benchmark]
                     else
                       Dir['data/datasets/*'].map do |path|
                         path.split('/').last
                       end
                     end

        benchmarks.shuffle.each do |benchmark|
          samples = Dir["data/datasets/#{benchmark}/*.yml"].map(&:to_s)

          samples.shuffle.each do |sample|
            models.shuffle.each do |model|
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

      def self.score_latency_streaming_prompt(benchmark, model, cartridge_path, prompt)
        evaluation_id = Logic::Identifier.cartridge_with_prompt(cartridge_path, prompt)

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
          YAML.safe_load_file("#{path}/#{file}", permitted_classes: [Symbol])
        )

        puts "\n# #{benchmark}@#{model}"

        timeline = evaluation[:timeline]

        started = timeline.min { |event| event[:at] }[:at]
        finished = timeline.max { |event| event[:at] }[:at]
        content = timeline.find { |event| event[:event] == 'finished' }[:content]
        first_fragmet_at = timeline.find { |event| event[:event] == 'stream' }[:at]

        complete_flow_time = elapsed_time(started, finished)
        first_fragmet_time = elapsed_time(started, first_fragmet_at)

        characters_per_second = content.length.to_f / complete_flow_time[:seconds]

        intervals_timeline = [
          timeline.find { |event| event[:event] == 'started' },
          timeline.filter do |event|
            event[:event] == 'stream' && !event[:fragment].nil? && event[:fragment].to_s.strip != ''
          end,
          timeline.find { |event| event[:event] == 'finished' }
        ].flatten

        intervals = intervals_timeline.each_cons(2).map do |a, b|
          elapsed_time(a[:at], b[:at])[:milliseconds]
        end

        fragments_length = timeline.filter do |event|
          event[:event] == 'stream' && !event[:fragment].nil?
        end.map do |event|
          event[:fragment].length.to_f
        end

        top_1 = top_n_percent_higher(intervals, 1, 1)
        top_10 = top_n_percent_higher(intervals, 10, 2)

        streaming = {
          top_1_higher_average: {
            milliseconds: top_1.sum.to_f / top_1.size,
            relative_to_time_to_complete: (
              (top_1.sum.to_f / top_1.size) / complete_flow_time[:milliseconds]
            )
          },
          top_10_higher_average: {
            milliseconds: top_10.sum.to_f / top_10.size,
            relative_to_time_to_complete: (
              (top_10.sum.to_f / top_10.size) / complete_flow_time[:milliseconds]
            )
          },
          max: {
            milliseconds: intervals.max,
            characters: fragments_length.max.to_i,
            relative_to_time_to_complete: intervals.max / complete_flow_time[:milliseconds]
          },
          min: {
            milliseconds: intervals.min,
            characters: fragments_length.min.to_i,
            relative_to_time_to_complete: intervals.min / complete_flow_time[:milliseconds]
          },
          average: {
            milliseconds: intervals.sum.to_f / intervals.size,
            relative_to_time_to_complete: (
              (intervals.sum.to_f / intervals.size) / complete_flow_time[:milliseconds]
            ),
            characters: fragments_length.sum.to_f / fragments_length.size,
            characters_relative_to_full_output: (fragments_length.sum.to_f / fragments_length.size) / content.length.to_f
          }
        }

        first_fragmet_time[:relative_to_time_to_complete] = (
          first_fragmet_time[:nanoseconds] / complete_flow_time[:nanoseconds]
        )

        score = {
          time_to_complete: complete_flow_time,
          time_to_first_character: first_fragmet_time,
          characters_per_second:,
          streaming:
        }

        data = {
          meta: {
            id: evaluation_id,
            benchmark:,
            model:,
            'generated-at': at.iso8601
          },
          environment: Components::Environment.details,
          score:,
          evaluation: evaluation[:timeline]
        }

        yaml_data = YAML.dump(Logic::Printer.stringify_keys(data))

        puts "\n> #{score_path}/#{file}"

        FileUtils.mkdir_p(score_path)
        File.write("#{score_path}/#{file}", yaml_data)
      end

      def self.top_n_percent_higher(values, target, min)
        sorted_values = values.sort.reverse

        count = [min, (sorted_values.length * (target.to_f / 100.0)).ceil].max

        sorted_values.first(count)
      end

      def self.score_latency_streaming(benchmark, model, cartridge_path, sample_path)
        samples = YAML.safe_load_file(
          sample_path, permitted_classes: [Symbol]
        )['samples']

        samples.each_key do |kind|
          samples[kind].each do |sample|
            score_latency_streaming_prompt(benchmark, model, cartridge_path, sample)
          end
        end
      end

      def self.elapsed_time(start_time, end_time)
        elapsed_time_ns = end_time.to_f - start_time.to_f

        {
          nanoseconds: elapsed_time_ns,
          microseconds: elapsed_time_ns / 1_000.0,
          milliseconds: elapsed_time_ns / 1_000_000.0,
          seconds: elapsed_time_ns / 1_000_000_000.0
        }
      end

      def self.score_sample(benchmark, model, _cartridge, raw_cartridge, cartridge_path, sample_path)
        if benchmark == 'latency-streaming'
          return score_latency_streaming(
            benchmark, model, cartridge_path, sample_path
          )
        end

        raw_sample = File.read(sample_path)

        legacy_evaluation_id = Digest::SHA256.hexdigest("#{raw_cartridge}\n#{raw_sample}")

        new_evaluation_id = Logic::Identifier.cartridge_with_sample(cartridge_path, sample_path)

        path = "data/evaluations/#{benchmark}/#{model}"
        legacy_file = "#{legacy_evaluation_id}.yml"
        new_file = "#{new_evaluation_id}.yml"

        unless File.exist?("#{path}/#{new_file}")
          puts "Sample '#{new_evaluation_id}' not evaluated yet for '#{model}'."
          return
        end

        score_path = "data/scores/#{benchmark}/#{model}"

        if File.exist?("#{score_path}/#{legacy_file}")
          to_migrate = YAML.safe_load_file("#{score_path}/#{legacy_file}", permitted_classes: [Symbol])

          to_migrate['meta']['id'] = new_evaluation_id

          File.write("#{score_path}/#{new_file}", YAML.dump(to_migrate))
          File.delete("#{score_path}/#{legacy_file}")

          puts "[MIGRATED] Sample '#{new_evaluation_id}' already scored for '#{model}'."
          return
        elsif File.exist?("#{score_path}/#{new_file}")
          evaluation = Logic::Printer.symbolize_keys(
            YAML.safe_load_file("#{path}/#{new_file}", permitted_classes: [Symbol])
          )

          sample = evaluation[:sample]
          expected = sample&.keys&.find { |key| key.to_s.include?('expect') }

          if expected
            to_upgrade = YAML.safe_load_file("#{score_path}/#{new_file}", permitted_classes: [Symbol])

            unless to_upgrade.key?('sample')
              to_upgrade = insert_before_key(
                to_upgrade, 'sample', { expected => sample[expected] }, 'score'
              )

              yaml_data = YAML.dump(Logic::Printer.stringify_keys(to_upgrade))

              File.write("#{score_path}/#{new_file}", yaml_data)

              puts "[MIGRATED] Sample '#{new_evaluation_id}' already scored for '#{model}'."
            end
          else
            puts "Sample '#{new_evaluation_id}' already scored for '#{model}'."
          end
          return
        end

        at = Time.now

        evaluation = Logic::Printer.symbolize_keys(
          YAML.safe_load_file("#{path}/#{new_file}", permitted_classes: [Symbol])
        )

        sample = evaluation[:sample]
        expected = sample&.keys&.find { |key| key.to_s.include?('expect') }

        puts "\n# #{benchmark}@#{model}"

        bot = if benchmark.start_with?('MMLU')
                NanoBot.new(cartridge: 'cartridges/benchmarks/MMLU/scorer.yml')
              elsif benchmark.start_with?('ENEM')
                NanoBot.new(cartridge: 'cartridges/benchmarks/ENEM/scorer.yml')
              else
                NanoBot.new(cartridge: "cartridges/benchmarks/#{benchmark}/scorer.yml")
              end

        input = if benchmark.start_with?('MMLU')
                  evaluation[:result]
                  "The expected correct answer option for this question is: #{evaluation[:sample][:'expected-answer']})\nBased on that, please analyze and score the following evaluation:\n```json\n#{JSON.pretty_generate(
                    evaluation[:result], indent: '  '
                  )}\n```"
                elsif benchmark.start_with?('ENEM')
                  evaluation[:result]
                  "A opção de resposta correta esperada para esta questão é: #{evaluation[:sample][:'expected-answer']})\nCom base nisso, por favor, analise e pontue a seguinte avaliação:\n```json\n#{JSON.pretty_generate(
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
            id: new_evaluation_id,
            benchmark:,
            model:,
            'generated-at': at.iso8601
          },
          environment: Components::Environment.details,
          score: JSON.parse(score),
          evaluation: evaluation[:result]
        }

        if expected
          data = insert_before_key(
            data, :sample, { expected => sample[expected] }, :score
          )
        end

        yaml_data = YAML.dump(Logic::Printer.stringify_keys(data))

        puts "\n> #{score_path}/#{new_file}"

        FileUtils.mkdir_p(score_path)
        File.write("#{score_path}/#{new_file}", yaml_data)
      end

      def self.insert_before_key(original_hash, new_key, new_value, before_key)
        original_hash.each_with_object({}) do |(key, value), new_hash|
          new_hash[new_key] = new_value if key == before_key && !new_hash.key?(new_key)
          new_hash[key] = value
        end
      end
    end
  end
end
