# frozen_string_literal: true

require 'nano-bots'
require 'securerandom'
require 'fileutils'
require 'json'

require_relative '../logic/printer'
require_relative '../components/environment'
require_relative '../components/elastic'

module LBPE
  module Controllers
    module Generator
      DEBUG = false

      def self.store_sample!(elastic, benchmark, target, seed, cartridge, input, sample)
        if count_samples(benchmark) >= target
          puts "\nYou already have #{count_samples(benchmark)} samples."
          exit
        end

        search = elastic.search(benchmark, sample)

        if search.dig(0, :score) && search.dig(0, :score) > 20
          puts "\nSample duplicated (score: #{search.dig(0, :score)}); skipping..."
          if DEBUG
            puts '-' * 20
            puts Components::Elastic.flatten_hash_values(sample).join("\n")
            puts '-' * 20
            puts search.dig(0, :content)
            puts '-' * 20
          end
          return
        end

        at = Time.now
        id = SecureRandom.hex
        data = {
          meta: {
            id: id,
            benchmark: benchmark,
            'generated-at': at.iso8601,
            seed: seed
          },
          environment: Components::Environment.details,
          sample: sample,
          input: input,
          cartridge: cartridge
        }

        elastic.index!(benchmark, sample)

        path = "data/datasets/#{benchmark}"
        file = "#{at.strftime('%Y-%m-%d-%H-%M-%S')}-#{id}.yml"

        yaml_data = YAML.dump(Logic::Printer.stringify_keys(data))

        puts "\n> #{path}/#{file}"
        puts Logic::Printer.pretty(sample, as: 'yaml')

        FileUtils.mkdir_p(path)
        File.write("#{path}/#{file}", yaml_data)
      end

      def self.count_samples(benchmark)
        Dir["data/datasets/#{benchmark}/*.yml"].count
      end

      def self.random_samples(benchmark, size)
        Dir["data/datasets/#{benchmark}/*.yml"].shuffle.slice(0, size).map do |path|
          YAML.safe_load(File.read(path), permitted_classes: [Symbol])['sample']
        end
      end

      def self.index_samples!(elastic, benchmark)
        Dir["data/datasets/#{benchmark}/*.yml"].each do |path|
          sample = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
          elastic.index!(benchmark, sample['sample'])
        end
      end

      def self.handle!(benchmark, samples, target)
        if count_samples(benchmark) >= target
          puts "You already have #{count_samples(benchmark)} samples."
          exit
        end

        elastic = Components::Elastic.instance
        raise 'Elasticsearch unavailable.' unless elastic.client.ping

        puts "Recreating index for '#{benchmark}'"

        elastic.reset_index!(benchmark)

        puts "\nIndexing #{count_samples(benchmark)} samples..."

        index_samples!(elastic, benchmark)

        cartridge = YAML.safe_load(
          File.read("cartridges/benchmarks/#{benchmark}/generator.yml"),
          permitted_classes: [Symbol]
        )

        while count_samples(benchmark) < target
          puts "\n> #{count_samples(benchmark)} samples generated so far."

          seed = rand(100..10**21)

          cartridge['provider']['settings']['seed'] = seed

          bot = NanoBot.new(cartridge: "cartridges/benchmarks/#{benchmark}/generator.yml")

          duplicated = { samples: random_samples(benchmark, 10) }

          input = ''

          if duplicated[:samples].size.positive?
            input += 'I already have the following samples:'

            input += "\n\n```json\n#{JSON.pretty_generate(duplicated, indent: '  ')}```\n\n"

            input += "So, try to avoid similar ones and come up with new ideas.\n"
          end

          input += "Now, generate an array containing precisely #{samples} samples in JSON format."

          puts ''

          output = bot.eval(input) do |_content, fragment, _finished, _meta|
            if DEBUG
              print fragment unless fragment.nil?
            else
              print '.' unless fragment.nil?
            end
          end

          puts ''

          parsed = JSON.parse(output)

          parsed['samples'].each do |sample|
            store_sample!(elastic, benchmark, target, seed, cartridge, input, sample)
          end
        end
      end
    end
  end
end
