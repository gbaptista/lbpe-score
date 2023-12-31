# frozen_string_literal: true

require 'digest'
require 'fileutils'

require_relative '../../logic/printer'
require_relative '../../logic/identifier'
require_relative '../../components/environment'

module LBPE
  module Controllers
    module Evaluator
      module LatencyStreaming
        def self.handle!(models, _benchmark)
          models = Dir["cartridges/models/#{models}/*/*.yml"].map do |path|
            path.sub('cartridges/models/', '').sub('.yml', '')
          end

          samples = YAML.safe_load_file(
            'data/datasets/latency-streaming/samples.yml', permitted_classes: [Symbol]
          )['samples']

          samples.each_key do |kind|
            samples[kind].each do |sample|
              models.each do |model|
                evaluate_model('latency-streaming', model, sample)
              end
            end
          end
        end

        def self.evaluate_model(benchmark, model, prompt)
          cartridge_path = "cartridges/models/#{model}.yml"

          raw_cartridge = File.read(cartridge_path)

          cartridge = Logic::Printer.symbolize_keys(
            YAML.safe_load(raw_cartridge, permitted_classes: [Symbol])
          )

          evaluate_prompt(benchmark, model, cartridge, raw_cartridge, cartridge_path, prompt)
        end

        def self.evaluate_prompt(benchmark, model, cartridge, _raw_cartridge, cartridge_path, prompt)
          Logic::Printer.stringify_keys(
            Logic::Identifier.cartridge(cartridge_path, as_raw: true)
          )

          id = Logic::Identifier.cartridge_with_prompt(cartridge_path, prompt)

          path = "data/evaluations/#{benchmark}/#{model}"
          file = "#{id}.yml"

          if File.exist?("#{path}/#{file}")
            puts "Sample '#{id}' already evaluated for '#{model}'."
            return
          end

          at = Time.now

          puts "\n# #{benchmark}@#{model}"

          bot = NanoBot.new(cartridge: cartridge_path)

          timeline = []

          timeline << {
            at: Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond),
            event: 'started',
            prompt:
          }

          output = bot.eval(prompt) do |_content, fragment, _finished, _meta|
            timeline << {
              at: Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond),
              event: 'stream',
              fragment:
            }
            print fragment unless fragment.nil?
          end

          timeline << {
            at: Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond),
            event: 'finished',
            content: output
          }

          data = {
            meta: {
              id:,
              benchmark:,
              model:,
              'generated-at': at.iso8601
            },
            environment: Components::Environment.details,
            timeline:,
            cartridge:,
            prompt:
          }

          yaml_data = YAML.dump(Logic::Printer.stringify_keys(data))

          puts "\n> #{path}/#{file}"
          puts Logic::Printer.pretty(timeline, as: 'yaml')

          FileUtils.mkdir_p(path)
          File.write("#{path}/#{file}", yaml_data)
        rescue StandardError => e
          puts "Error evaluating '#{id}' for '#{model}': #{e.message}"
        end
      end
    end
  end
end
