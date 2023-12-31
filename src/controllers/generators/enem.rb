# frozen_string_literal: true

require_relative '../../logic/printer'
require_relative '../../components/environment'

require 'csv'

module LBPE
  module Controllers
    module Generator
      module ENEM
        def self.handle!(_set)
          Dir['data/raw/ENEM/*.jsonl'].each do |path|
            File.read(path).split("\n").shuffle.each do |line|
              generate_question(JSON.parse(line), path)
            end
          end
        end

        def self.generate_question(raw, path)
          year = path.split('/').last.sub('.jsonl', '')

          benchmark = "ENEM-#{year}"

          JSON.generate(raw)

          at = Time.now
          id = Digest::SHA256.hexdigest(JSON.generate(raw))

          sample = parse_question(raw)

          data = {
            meta: {
              id:,
              benchmark:,
              'generated-at': at.iso8601
            },
            environment: Components::Environment.details,
            sample:
          }
          path = "data/datasets/#{benchmark}"
          file = "#{at.strftime('%Y-%m-%d-%H-%M-%S')}-#{id}.yml"

          yaml_data = YAML.dump(Logic::Printer.stringify_keys(data))

          puts "\n> #{path}/#{file}"
          puts Logic::Printer.pretty(sample, as: 'yaml')

          FileUtils.mkdir_p(path)
          File.write("#{path}/#{file}", yaml_data)
        end

        def self.parse_question(raw)
          answer = raw['label']

          question = raw['question']

          replacement_enum = raw['description'].each
          question = question.gsub('[[placeholder]]') { replacement_enum.next }

          raw['alternatives'].each_with_index do |_content, index|
            raw['alternatives'][index] = raw['alternatives'][index].gsub('[[placeholder]]') do
              replacement_enum.next
            end
          end

          question = "Questão: #{question}\n\nOpções:\n\nA) #{raw['alternatives'][0]}\nB) #{raw['alternatives'][1]}\nC) #{raw['alternatives'][2]}\nD) #{raw['alternatives'][3]}\nD) #{raw['alternatives'][4]}\n\nComece aplicando conhecimentos relevantes para responder à pergunta. Analise cada opção, considerando os princípios, fatos e lógica específicos ao tema da questão. Forneça uma análise detalhada para cada opção."

          {
            user: [
              question,
              'Baseado em sua análise e raciocínio, qual opção parece mais justificável e a resposta correta?',
              'Forneça apenas a letra da opção com a resposta correta.'
            ],
            'expected-answer': answer
          }
        end
      end
    end
  end
end
