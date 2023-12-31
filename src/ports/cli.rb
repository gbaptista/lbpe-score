# frozen_string_literal: true

require 'dotenv/load'

require_relative '../static/meta'
require_relative '../logic/printer'
require_relative '../controllers/generator'
require_relative '../controllers/generators/mmlu'
require_relative '../controllers/generators/enem'
require_relative '../controllers/evaluator'
require_relative '../controllers/evaluators/latency_streaming'
require_relative '../controllers/scorer'
require_relative '../controllers/reporter'
require_relative '../controllers/csv_exporter'

module LBPE
  module Ports
    module CLI
      def self.handle!
        case ARGV[0]
        when 'version'
          puts Logic::Printer.pretty(META, as: 'yaml')
        when 'csv'
          Controllers::CSVExporter.handle!(ARGV[1])
        when 'generate'
          if ARGV[1] == 'MMLU'
            Controllers::Generator::MMLU.handle!(ARGV[2])
          elsif ARGV[1] == 'ENEM'
            Controllers::Generator::ENEM.handle!(ARGV[2])
          else
            Controllers::Generator.handle!(ARGV[1], ARGV[2].to_i, ARGV[3].to_i)
          end
        when 'eval'
          if ARGV[2] == 'latency-streaming'
            Controllers::Evaluator::LatencyStreaming.handle!(ARGV[1], ARGV[2])
          else
            Controllers::Evaluator.handle!(ARGV[1], ARGV[2], ARGV[3])
          end
        when 'score'
          Controllers::Scorer.handle!(ARGV[1])
        when 'report'
          Controllers::Reporter.handle!
        when 'details'
          Controllers::Reporter.details(ARGV[1], ARGV[2])
        else
          puts "Unknown command: #{ARGV[0]}"
        end
      end
    end
  end
end

LBPE::Ports::CLI.handle! if __FILE__ == $PROGRAM_NAME
