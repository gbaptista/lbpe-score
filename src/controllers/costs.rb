# frozen_string_literal: true

require 'openai'

require_relative '../logic/printer'

module LBPE
  module Controllers
    module Costs
      def self.handle!
        puts 'TODO'
        Dir['../lbpe-score-BACKUP/data/datasets/MMLU-*/*.yml'].map do |path|
          YAML.safe_load_file(path, permitted_classes: [Symbol])
        end

        samples = Dir['../lbpe-score-BACKUP/data/datasets/MMLU-*/*.yml'].map do |path|
          YAML.safe_load_file(path, permitted_classes: [Symbol])
        end

        evals = Dir['../lbpe-score-BACKUP/data/evaluations/MMLU-*/*/*/*/*.yml'].map do |path|
          YAML.safe_load_file(path, permitted_classes: [Symbol])
        end

        scores = Dir['../lbpe-score-BACKUP/data/scores/MMLU-*/*/*/*/*.yml'].map do |path|
          YAML.safe_load_file(path, permitted_classes: [Symbol])
        end

        questions_tokens = samples.sum do |sample|
          sample['sample']['user'].sum do |message|
            OpenAI.rough_token_count(message)
          end + OpenAI.rough_token_count(sample['sample']['expected-answer'])
        end

        evals_tokens = evals.sum do |sample|
          sample['result'].sum { |item| OpenAI.rough_token_count(item['content']) }
        end

        scores_tokens = scores.sum do |sample|
          OpenAI.rough_token_count(sample['score']['analysis'])
        end

        total = 4 * (questions_tokens + evals_tokens + scores_tokens)

        price = (total.to_f / 1000.0) * 0.03

        puts total
        puts price
      end
    end
  end
end
