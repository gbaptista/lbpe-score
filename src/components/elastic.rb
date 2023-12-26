# frozen_string_literal: true

require 'elasticsearch'

module LBPE
  module Components
    class Elastic
      include Singleton

      INDEX = {
        settings: {
          analysis: {
            analyzer: {
              shingle_analyzer: {
                type: 'custom',
                tokenizer: 'standard',
                filter: %w[lowercase shingle_filter]
              }
            },
            filter: {
              shingle_filter: {
                type: 'shingle',
                min_shingle_size: 2,
                max_shingle_size: 3
              }
            }
          }
        },
        mappings: {
          properties: {
            content: {
              type: 'text',
              analyzer: 'shingle_analyzer'
            }
          }
        }
      }.freeze

      def client
        @client ||= Elasticsearch::Client.new(host: ENV.fetch('ELASTICSEARCH_HOST', nil))
      end

      def reset_index!(benchmark)
        begin
          @client.indices.delete(index: benchmark)
        rescue StandardError
        end

        @client.indices.create(index: benchmark, body: INDEX)
      end

      def index!(benchmark, object)
        @client.index(
          index: benchmark,
          body: { content: Elastic.flatten_hash_values(object).join("\n") }
        )
      end

      def search(benchmark, object)
        body = {
          size: 3,
          query: {
            more_like_this: {
              fields: ['content'],
              like: Elastic.flatten_hash_values(object).join("\n"),
              min_term_freq: 1,
              max_query_terms: 12,
              min_doc_freq: 1
            }
          }
        }

        response = @client.search(index: benchmark, body:)

        hits = response.body.dig('hits', 'hits')

        return hits if !hits || hits.empty?

        hits.map do |hit|
          { score: hit['_score'], content: hit['_source']['content'] }
        end
      end

      def self.flatten_hash_values(obj, result = [])
        case obj
        when Hash
          obj.each_value do |value|
            flatten_hash_values(value, result)
          end
        when Array
          obj.each do |value|
            flatten_hash_values(value, result)
          end
        else
          result << obj
        end
        result.flatten
      end
    end
  end
end
