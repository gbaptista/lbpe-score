# frozen_string_literal: true

require 'openai'

require_relative '../logic/printer'

module LBPE
  module Controllers
    module Reporter
      def self.handle!
        results = { 'benchmarks' => generate_report }

        results['benchmarks'].each do |key, model_scores|
          model_scores.each do |model, scores|
            total = scores.values.sum

            target = case key
                     when 'MMLU'
                       1_760
                     when 'ENEM'
                       360
                     when 'language-1'
                       30
                     else
                       100
                     end

            difference = target - total
            model_scores[model] = { 0 => difference }.merge(scores)
          end
        end

        percentage = {}

        results['benchmarks'].each do |benchmark, model_scores|
          model_scores.each do |model, scores|
            percentage[benchmark] = Hash.new { |hash, key| hash[key] = Hash.new(0) } unless percentage.key?(benchmark)
            scores.each do |score, value|
              if score >= 4
                percentage[benchmark][model][:success] += value
              else
                percentage[benchmark][model][:failure] += value
              end
            end
          end

          model_scores.each_key do |model|
            percentage[benchmark][model][:percentage] = (
              percentage[benchmark][model][:success].to_f /
              (percentage[benchmark][model][:success].to_f + percentage[benchmark][model][:failure].to_f)
            )
          end
        end

        results['percentage'] = percentage

        results = generate_latency_streaming(results)
        results = generate_pricing(results)

        radar = {
          'tools' => %w[tools-1 tools-2],
          'bafc' => %w[conversational-recall-1 conversational-recall-2
                       conversational-recall-3 conversational-recall-4],
          'language' => ['language-1'],
          'mmlu' => ['MMLU'],
          'enem' => ['ENEM'],
          'stream' => [
            'stream/RTTFC', 'stream/RTTFC', 'stream/RTTFC', 'stream/RTTFC', 'stream/RTTFC',
            'stream/RTTFC', 'stream/RTTFC', 'stream/RTTFC', 'stream/RTTFC', 'stream/RTTFC',
            'stream/ARTTTC', 'stream/ACRTFO'
          ],
          'latency' => ['latency/CPS'],
          'pricing' => [
            'pricing/input/usd/1M-tokens',

            'pricing/output/usd/1M-tokens',
            'pricing/output/usd/1M-tokens',

            'pricing/output/average-tokens',

            'pricing/output/average-USD-cost-10k-prompts',
            'pricing/output/average-USD-cost-10k-prompts',
            'pricing/output/average-USD-cost-10k-prompts'
          ]
        }

        models = Dir['cartridges/models/standard/*/*.yml'].map do |raw|
          "#{raw.split('/')[-2]}/#{raw.split('/')[-1].sub('.yml', '')}"
        end

        results['radar'] = {}

        models.each do |model|
          radar.each_key do |radar_key|
            results['radar'][model] = {} unless results['radar'].key?(model)

            results['radar'][model][radar_key] = average(
              radar[radar_key].map do |benchmark|
                value = results.dig('percentage', benchmark, model, :percentage)
                value.nil? ? 0.0 : value
              end
            )
          end
        end

        results['consolidated'] = {}

        results['radar'].each_key do |model|
          results['radar'][model].each_key do |benchmark|
            results['consolidated'][benchmark] = {} unless results['consolidated'].key?(benchmark)
            results['consolidated'][benchmark][model] = {
              'percentage' => results['radar'][model][benchmark]
            }
          end
        end

        results = { 'meta' => { 'generated_at' => Time.now } }.merge(results)

        File.write(
          'docs/data/report.json',
          JSON.pretty_generate(results, indent: '  ')
        )

        puts Logic::Printer.pretty(results, as: 'yaml')
      end

      def self.add_to_latency_streaming(results, benchmark, model, value)
        results['benchmarks'][benchmark] = {} unless results['benchmarks'].key?(benchmark)

        results['benchmarks'][benchmark][model] = [] unless results['benchmarks'][benchmark].key?(model)

        results['benchmarks'][benchmark][model] << value

        results['percentage'][benchmark] = {} unless results['percentage'].key?(benchmark)

        results['percentage'][benchmark][model] = [] unless results['percentage'][benchmark].key?(model)

        results['percentage'][benchmark][model] << value

        results
      end

      def self.generate_pricing(results)
        # As of December 30, 2023:
        # https://openai.com/pricing
        # https://ai.google.dev/pricing
        # https://docs.mistral.ai/platform/pricing/
        # https://cohere.com/pricing

        exchange_to_usd = { 'EUR' => 1.1056, 'BRL' => 0.2057 }

        prices = {
          'openai/gpt-4-turbo' => {
            input: {
              amount: 0.01,
              currency: 'USD',
              per: {
                amount: 1000,
                unit: 'tokens'
              }
            },
            output: {
              amount: 0.03,
              currency: 'USD',
              per: {
                amount: 1000,
                unit: 'tokens'
              }
            }
          },
          'openai/gpt-3-5-turbo' => {
            input: {
              amount: 0.0010,
              currency: 'USD',
              per: {
                amount: 1000,
                unit: 'tokens'
              }
            },
            output: {
              amount: 0.0020,
              currency: 'USD',
              per: {
                amount: 1000,
                unit: 'tokens'
              }
            }
          },
          'google/gemini-pro' => {
            input: {
              amount: 0.00025,
              currency: 'USD',
              per: {
                amount: 1000,
                unit: 'characters'
              }
            },
            output: {
              amount: 0.0005,
              currency: 'USD',
              per: {
                amount: 1000,
                unit: 'characters'
              }
            }
          },
          'mistral/tiny' => {
            input: {
              amount: 0.14,
              currency: 'EUR',
              per: {
                amount: 1_000_000,
                unit: 'tokens'
              }
            },
            output: {
              amount: 0.42,
              currency: 'EUR',
              per: {
                amount: 1_000_000,
                unit: 'tokens'
              }
            }
          },
          'mistral/small' => {
            input: {
              amount: 0.6,
              currency: 'EUR',
              per: {
                amount: 1_000_000,
                unit: 'tokens'
              }
            },
            output: {
              amount: 1.8,
              currency: 'EUR',
              per: {
                amount: 1_000_000,
                unit: 'tokens'
              }
            }
          },
          'mistral/medium' => {
            input: {
              amount: 2.5,
              currency: 'EUR',
              per: {
                amount: 1_000_000,
                unit: 'tokens'
              }
            },
            output: {
              amount: 7.5,
              currency: 'EUR',
              per: {
                amount: 1_000_000,
                unit: 'tokens'
              }
            }
          },
          'cohere/command' => {
            input: {
              amount: 1.00,
              currency: 'USD',
              per: {
                amount: 1_000_000,
                unit: 'tokens'
              }
            },
            output: {
              amount: 2.00,
              currency: 'USD',
              per: {
                amount: 1_000_000,
                unit: 'tokens'
              }
            }
          },
          'cohere/command-light' => {
            input: {
              amount: 0.30,
              currency: 'USD',
              per: {
                amount: 1_000_000,
                unit: 'tokens'
              }
            },
            output: {
              amount: 0.60,
              currency: 'USD',
              per: {
                amount: 1_000_000,
                unit: 'tokens'
              }
            }
          },
          'maritaca/maritalk' => {
            input: {
              amount: 5.00,
              currency: 'BRL',
              per: {
                amount: 1_000_000,
                unit: 'tokens'
              }
            },
            output: {
              amount: 5.00,
              currency: 'BRL',
              per: {
                amount: 1_000_000,
                unit: 'tokens'
              }
            }
          }
        }

        reference_text = 'What are some benefits of learning multiple languages?'

        tokens_per_character = (
          OpenAI.rough_token_count(reference_text).to_f / reference_text.length
        )

        prices.each_key do |model|
          add_to_pricing(
            results, 'pricing/input/usd/1M-tokens', model,
            normalize_price(prices[model][:input], exchange_to_usd, tokens_per_character)
          )

          add_to_pricing(
            results, 'pricing/output/usd/1M-tokens', model,
            normalize_price(prices[model][:output], exchange_to_usd, tokens_per_character)
          )
        end

        average_tokens = {}

        Dir['data/evaluations/*/*/*/*/*.yml'].each do |path|
          result = Logic::Printer.symbolize_keys(
            YAML.safe_load_file(path, permitted_classes: [Symbol])
          )

          next unless result[:result].is_a?(Array)

          model = "#{path.split('/')[-3]}/#{path.split('/')[-2]}"

          result[:result].each do |message|
            unless message.is_a?(Hash) && message[:role] == 'model' && message[:content].to_s.strip.length.positive?
              next
            end

            average_tokens[model] = [] unless average_tokens.key?(model)
            average_tokens[model] << OpenAI.rough_token_count(message[:content]).to_f
          end
        end

        average_tokens.each_key do |model|
          average_tokens[model] = average_tokens[model].sum / average_tokens[model].count.to_f

          usd_per_1M = results['benchmarks']['pricing/output/usd/1M-tokens'][model]

          add_to_pricing(
            results, 'pricing/output/average-tokens', model,
            average_tokens[model]
          )

          add_to_pricing(
            results, 'pricing/output/average-USD-cost-10k-prompts', model,
            average_tokens[model] * (usd_per_1M.to_f / 1_000_000) * 10_000
          )
        end

        [
          'pricing/input/usd/1M-tokens',
          'pricing/output/usd/1M-tokens',
          'pricing/output/average-tokens',
          'pricing/output/average-USD-cost-10k-prompts'
        ].each do |benchmark|
          results['percentage'][benchmark].values.map { |model| model[:percentage] }.max.to_f
                                          .ceil

          min = results['percentage'][benchmark].values.map { |model| model[:percentage] }.min.to_f

          results['percentage'][benchmark].each_key do |model|
            # if benchmark == 'pricing/output/average-tokens'
            #   require 'pry'; binding.pry
            # end
            results['percentage'][benchmark][model][:percentage] = (
              min / results['percentage'][benchmark][model][:percentage].to_f
            )
          end
        end

        results
      end

      def self.normalize_price(price, exchange_to_usd, tokens_per_character)
        usd = price[:amount]
        usd = usd.to_f * exchange_to_usd[price[:currency]].to_f if price[:currency] != 'USD'

        tokens = price[:per][:amount]

        tokens = tokens.to_f * tokens_per_character.to_f if price[:per][:unit] == 'characters'

        usd_per_token = usd.to_f / tokens

        usd_per_token * 1_000_000.0
      end

      def self.add_to_pricing(results, benchmark, model, value)
        results['benchmarks'][benchmark] = {} unless results['benchmarks'].key?(benchmark)

        results['benchmarks'][benchmark][model] = value unless results['benchmarks'][benchmark].key?(model)

        results['percentage'][benchmark] = {} unless results['percentage'].key?(benchmark)

        unless results['percentage'][benchmark].key?(model)
          results['percentage'][benchmark][model] =
            { percentage: value }
        end

        results
      end

      def self.generate_latency_streaming(results)
        Dir['data/scores/latency-streaming/*/*/*/*.yml'].map do |path|
          result = Logic::Printer.symbolize_keys(
            YAML.safe_load_file(path, permitted_classes: [Symbol])
          )

          model = result[:meta][:model]
          score = result[:score]

          model = model.split('/').last(2).join('/')

          # Characters count / completion time in seconds for the request.
          results = add_to_latency_streaming(
            results, 'latency/CPS', model,
            score[:characters_per_second]
          )

          # How fast was the first character received compared to the total request time?
          results = add_to_latency_streaming(
            results, 'stream/RTTFC', model,
            1.0 - score[:time_to_first_character][:relative_to_time_to_complete]
          )

          # The average speed of the slowest 10% of streaming events during a request's total duration.
          results = add_to_latency_streaming(
            results, 'stream/ARTTTC', model,
            1.0 - score[:streaming][:top_10_higher_average][:relative_to_time_to_complete]
          )

          # Average characters per stream event compared to final output characters count.
          results = add_to_latency_streaming(
            results, 'stream/ACRTFO', model,
            1.0 - score[:streaming][:average][:characters_relative_to_full_output]
          )
        end

        ['latency/CPS', 'stream/RTTFC', 'stream/ARTTTC', 'stream/ACRTFO'].each do |benchmark|
          %w[benchmarks percentage].each do |kind|
            results[kind][benchmark].each_key do |model|
              results[kind][benchmark][model] = average(
                results[kind][benchmark][model]
              )
              next unless kind == 'percentage'

              results[kind][benchmark][model] = {
                percentage: results[kind][benchmark][model]
              }
            end
          end
        end

        ['latency/CPS'].each do |benchmark|
          max =
            results['percentage'][benchmark].values.map { |model| model[:percentage] }.max.to_f
                                            .ceil
          results['percentage'][benchmark].each_key do |model|
            results['percentage'][benchmark][model][:percentage] = (
              results['percentage'][benchmark][model][:percentage].to_f / max
            )
          end
        end

        results
      end

      def self.details(benchmark, model)
        results = generate_report
        details = generate_report(details: true)

        scores = results[benchmark][model]
        detail = details[benchmark][model]

        puts Logic::Printer.pretty(scores, as: 'yaml')

        detail[1].slice(0, 5).each do |sample|
          puts '-' * 20
          puts Logic::Printer.pretty(sample[:evaluation], as: 'yaml')
          puts '-' * 20
        end

        detail[5].slice(0, 5).each do |sample|
          puts '-' * 20
          puts Logic::Printer.pretty(sample[:evaluation], as: 'yaml')
          puts '-' * 20
        end
      end

      def self.generate_report(details: false)
        results = {}

        Dir['data/scores/*/*/*/*/*.yml'].map do |path|
          result = Logic::Printer.symbolize_keys(
            YAML.safe_load_file(path, permitted_classes: [Symbol])
          )

          benchmark = if result[:meta][:benchmark].start_with?('MMLU')
                        'MMLU'
                      elsif result[:meta][:benchmark].start_with?('ENEM')
                        'ENEM'
                      else
                        result[:meta][:benchmark]
                      end

          next if benchmark == 'latency-streaming'

          model = result[:meta][:model]
          score = result[:score][:score]

          model = model.split('/').last(2).join('/')

          results[benchmark] = {} unless results.key?(benchmark)

          unless results[benchmark].key?(model)
            results[benchmark][model] = if details
                                          {
                                            1 => [], 2 => [], 3 => [], 4 => [], 5 => []
                                          }
                                        else
                                          {
                                            1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0
                                          }
                                        end
          end

          if details
            results[benchmark][model][score] << result
          else
            results[benchmark][model][score] += 1
          end
        rescue StandardError => e
          puts path
          puts e.message
        end

        results
      end

      def self.average(array)
        return 0.0 if array.empty?

        array.sum.to_f / array.size
      end
    end
  end
end
