# frozen_string_literal: true

require 'digest'
require 'fileutils'

require_relative '../logic/printer'
require_relative '../logic/identifier'
require_relative '../components/environment'

module LBPE
  module Controllers
    module Evaluator
      def self.handle!(models, benchmark, sample_path)
        models = Dir["cartridges/models/#{models}/*/*.yml"].map do |path|
          path.sub('cartridges/models/', '').sub('.yml', '')
        end

        samples = if sample_path.nil?
                    if benchmark == 'MMLU'
                      items = Dir["data/datasets/#{benchmark}-*/*.yml"].count
                      raise "Unexpected number of items for MMLU: #{items}" if items != 1760

                      Dir["data/datasets/#{benchmark}-*/*.yml"].map(&:to_s)
                    elsif benchmark == 'ENEM'
                      items = Dir["data/datasets/#{benchmark}-*/*.yml"].count
                      raise "Unexpected number of items for ENEM: #{items}" if items != 360

                      Dir["data/datasets/#{benchmark}-*/*.yml"].map(&:to_s)
                    else
                      Dir["data/datasets/#{benchmark}/*.yml"].map(&:to_s)
                    end
                  else
                    [sample_path]
                  end

        samples.shuffle.each do |sample|
          models.shuffle.each do |model|
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

        clean_cartridge = Logic::Printer.stringify_keys(
          Logic::Identifier.cartridge(cartridge_path, as_raw: true)
        )

        legacy_id = Digest::SHA256.hexdigest("#{raw_cartridge}\n#{raw_sample}")

        new_id = Logic::Identifier.cartridge_with_sample(cartridge_path, sample_path)

        path = "data/evaluations/#{benchmark}/#{model}"
        legacy_file = "#{legacy_id}.yml"
        file = "#{new_id}.yml"

        if File.exist?("#{path}/#{legacy_file}")
          to_migrate = YAML.safe_load_file("#{path}/#{legacy_file}", permitted_classes: [Symbol])
          to_migrate['meta']['id'] = new_id
          to_migrate['cartridge'] = clean_cartridge
          File.write("#{path}/#{legacy_file}", YAML.dump(to_migrate))

          FileUtils.mv("#{path}/#{legacy_file}", "#{path}/#{file}")
          puts "[MIGRATED] Sample '#{new_id}' already evaluated for '#{model}'"
          return
        elsif File.exist?("#{path}/#{file}")
          puts "Sample '#{new_id}' already evaluated for '#{model}'."
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
            id: new_id,
            benchmark:,
            model:,
            'generated-at': at.iso8601
          },
          environment: Components::Environment.details,
          result:,
          cartridge:,
          sample: sample[:sample]
        }

        yaml_data = YAML.dump(Logic::Printer.stringify_keys(data))

        puts "\n> #{path}/#{file}"
        puts Logic::Printer.pretty(result, as: 'yaml')

        FileUtils.mkdir_p(path)
        File.write("#{path}/#{file}", yaml_data)
      rescue StandardError => e
        puts "Error evaluating '#{new_id}' for '#{model}': #{e.message}"
      end
    end
  end
end
