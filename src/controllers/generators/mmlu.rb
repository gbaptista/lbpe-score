# frozen_string_literal: true

require_relative '../../logic/printer'
require_relative '../../components/environment'

require 'csv'

module LBPE
  module Controllers
    module Generator
      module MMLU
        def self.handle!(set)
          Dir["data/raw/MMLU/#{set}/*.csv"].each do |path|
            field = path.split('/').last.sub("_#{set}.csv", '').gsub('_', ' ')
            generate_for_field(field, path)
          end
        end

        def self.generate_for_field(field, path)
          benchmark = 'MMLU'

          questions = []

          begin
            CSV.foreach(path, headers: false) { |row| questions << parse_question(field, row) }
          rescue StandardError => e
            puts "#{e.message} #{path}"
          end

          questions.each do |sample|
            at = Time.now
            id = Digest::SHA256.hexdigest("#{sample[:user].join("\n")}\n#{sample[:'expected-answer']}")

            data = {
              meta: {
                id: id,
                benchmark: benchmark,
                'generated-at': at.iso8601
              },
              environment: Components::Environment.details,
              sample: sample
            }
            path = "data/datasets/#{benchmark}-#{field.gsub(' ', '-')}"
            file = "#{at.strftime('%Y-%m-%d-%H-%M-%S')}-#{id}.yml"

            yaml_data = YAML.dump(Logic::Printer.stringify_keys(data))

            puts "\n> #{path}/#{file}"
            puts Logic::Printer.pretty(sample, as: 'yaml')

            FileUtils.mkdir_p(path)
            File.write("#{path}/#{file}", yaml_data)
          end
        end

        def self.parse_question(field, raw)
          answer = raw.pop

          question = "Question: #{raw[0]}\n\nOptions:\n\nA) #{raw[1]}\nB) #{raw[2]}\nC) #{raw[3]}\nD) #{raw[4]}\n\nBegin by applying relevant knowledge from #{field}. Analyze each option, considering the principles, facts, and logic specific to #{field}. Provide a detailed analysis for each option."

          {
            user: [
              question,
              'Based on your analysis and reasoning, which option seems most justifiable and the correct answer?',
              'Give me only the letter of the option with the correct answer.'
            ],
            'expected-answer': answer
          }
        end
      end
    end
  end
end
