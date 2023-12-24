# frozen_string_literal: true

require 'digest'

require_relative '../logic/printer'
require_relative '../components/environment'

module LBPE
  module Controllers
    module Evaluator
      def self.handle!(models, benchmark, sample_path)
        models = Dir["cartridges/models/#{models}/*/*.yml"].map do |path|
          path.sub('cartridges/models/', '').sub('.yml', '')
        end

        samples = if sample_path.nil?
                    Dir["data/datasets/#{benchmark}-*/*.yml"].map(&:to_s) if benchmark == 'MMLU'
                  else
                    [sample_path]
                  end

        samples.each do |sample|
          models.each do |model|
            evaluate_model(sample.split('/')[-2], model, sample)
          end
        end
      end

      def self.evaluate_model(benchmark, model, sample_path)
        cartridge_path = "cartridges/models/#{model}.yml"

        raw_cartridge = File.read(cartridge_path)

        cartridge = Logic::Printer.symbolize_keys(
          YAML.safe_load(raw_cartridge, permitted_classes: [Symbol])
        )

        evaluate_sample(benchmark, model, cartridge, raw_cartridge, cartridge_path, sample_path)
      end

      def self.evaluate_sample(benchmark, model, cartridge, raw_cartridge, cartridge_path, sample_path)
        raw_sample = File.read(sample_path)

        evaluation_id = Digest::SHA256.hexdigest("#{raw_cartridge}\n#{raw_sample}")

        path = "data/evaluations/#{benchmark}/#{model}"
        file = "#{evaluation_id}.yml"

        if File.exist?("#{path}/#{file}")
          puts "Sample '#{evaluation_id}' already evaluated for '#{model}'."
          return
        end

        at = Time.now

        sample = Logic::Printer.symbolize_keys(
          YAML.safe_load(
            raw_sample, permitted_classes: [Symbol]
          )
        )

        result = []

        puts "\n# #{benchmark}@#{model}"

        bot = NanoBot.new(cartridge: cartridge_path)

        sample[:sample][:user].each do |input|
          result << { role: 'user', content: input }

          puts "\n> #{input}\n\n"

          output = bot.eval(input) do |_content, fragment, _finished, _meta|
            print fragment unless fragment.nil?
          end

          puts ''

          result << { role: 'model', content: output }
        end

        data = {
          meta: {
            id: evaluation_id,
            benchmark: benchmark,
            model: model,
            'generated-at': at.iso8601
          },
          environment: Components::Environment.details,
          result: result,
          cartridge: cartridge,
          sample: sample[:sample]
        }

        yaml_data = YAML.dump(Logic::Printer.stringify_keys(data))

        puts "\n> #{path}/#{file}"
        puts Logic::Printer.pretty(result, as: 'yaml')

        FileUtils.mkdir_p(path)
        File.write("#{path}/#{file}", yaml_data)
      rescue StandardError => e
        puts "Error evaluating '#{evaluation_id}' for '#{model}': #{e.message}"
      end
    end
  end
end
