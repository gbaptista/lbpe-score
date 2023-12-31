# frozen_string_literal: true

require 'csv'
require 'json'

require_relative '../logic/printer'

module LBPE
  module Controllers
    module CSVExporter
      MODELS_LABELS = {
        'cohere/command-light' => 'Cohere Command Light',
        'cohere/command' => 'Cohere Command',
        'google/gemini-pro' => 'Google Gemini Pro',
        'maritaca/maritalk' => 'Maritaca MariTalk',
        'mistral/medium' => 'Mistral Medium',
        'mistral/small' => 'Mistral Small',
        'mistral/tiny' => 'Mistral Tiny',
        'openai/gpt-3-5-turbo' => 'OpenAI GPT-3.5 Turbo',
        'openai/gpt-4-turbo' => 'OpenAI GPT-4 Turbo'
      }.freeze

      SCORE_LABELS = {
        'bafc' => 'Back-and-Forth Conversations',
        'tools' => 'Tools (Functions)',
        'mmlu' => 'MMLU',
        'enem' => 'ENEM',
        'pricing' => 'Pricing',
        'stream' => 'Streaming',
        'latency' => 'Latency',
        'language' => 'Polyglotism'
      }.freeze

      def self.handle!(_)
        report = JSON.parse(File.read('docs/data/report.json'))

        lines = report['radar'].keys.map do |model|
          line = {
            'Model' => MODELS_LABELS[model] || model
          }

          report['radar'][model].keys.sort.each do |score|
            line[SCORE_LABELS[score] || score] = report['radar'][model][score]
          end

          line
        end

        CSV.open('docs/data/report.csv', 'wb') do |csv|
          csv << lines.first.keys
          lines.each do |line|
            csv << line.values
          end
        end

        puts 'CSV file generated at: docs/data/report.csv'
      end
    end
  end
end
