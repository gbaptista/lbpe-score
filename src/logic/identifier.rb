# frozen_string_literal: true

require 'yaml'
require 'digest'

require_relative 'printer'

module LBPE
  module Logic
    module Identifier
      def self.cartridge_with_prompt(cartridge_path, prompt)
        cartridge_raw = cartridge(cartridge_path, as_raw: true)

        Digest::SHA256.hexdigest("#{YAML.dump(cartridge_raw)}@#{YAML.dump(prompt)}")
      end

      def self.cartridge_with_sample(cartridge_path, sample_path)
        cartridge_raw = cartridge(cartridge_path, as_raw: true)
        sample_raw = sample(sample_path, as_raw: true)

        Digest::SHA256.hexdigest("#{YAML.dump(cartridge_raw)}@#{YAML.dump(sample_raw)}")
      end

      def self.sample(path, as_raw: false)
        raw = Logic::Printer.symbolize_keys(
          YAML.safe_load_file(path, permitted_classes: [Symbol])
        )

        deletion_paths = [[:environment]]

        deletion_paths.each do |path|
          raw = delete_exact_path(raw, path)
        end

        raw = recursively_sort_hash(delete_empty_collections(raw))

        return raw if as_raw

        Digest::SHA256.hexdigest(YAML.dump(raw))
      end

      def self.cartridge(path, as_raw: false)
        raw = Logic::Printer.symbolize_keys(
          YAML.safe_load_file(path, permitted_classes: [Symbol])
        )

        deletion_paths = [
          [:meta],
          [:miscellaneous],
          *%i[address access-token api-key region file-path project-id].map do |key|
            [:provider, :credentials, key]
          end
        ]

        deletion_paths.each do |path|
          raw = delete_exact_path(raw, path)
        end

        raw = recursively_sort_arrays(
          recursively_sort_hash(delete_empty_collections(raw))
        )

        return raw if as_raw

        Digest::SHA256.hexdigest(YAML.dump(raw))
      end

      def self.recursively_sort_hash(unsorted_hash)
        unsorted_hash.transform_values do |value|
          case value
          when Hash
            recursively_sort_hash(value)
          when Array
            value.map { |item| item.is_a?(Hash) ? recursively_sort_hash(item) : item }
          else
            value
          end
        end.sort.to_h
      end

      def self.recursively_sort_arrays(unsorted_hash)
        unsorted_hash.transform_values do |value|
          case value
          when Hash
            recursively_sort_arrays(value)
          when Array
            value.sort_by(&:to_yaml)
          else
            value
          end
        end.sort.to_h
      end

      def self.delete_exact_path(hash, path)
        return hash unless path.is_a?(Array) && !path.empty?

        delete_path_helper(hash, path)
      end

      def self.delete_path_helper(current_hash, current_path)
        return current_hash unless current_hash.is_a?(Hash)

        key = current_path.first

        if current_path.length == 1
          current_hash.delete(key)
        elsif current_hash.key?(key)
          current_hash[key] = delete_path_helper(current_hash[key], current_path[1..])
        end

        current_hash
      end

      def self.delete_empty_collections(hash)
        return unless hash.is_a?(Hash)

        hash.each do |key, value|
          if value.is_a?(Hash)
            delete_empty_collections(value)
            hash.delete(key) if value.empty?
          elsif value.is_a?(Array) && value.empty?
            hash.delete(key)
          end
        end

        hash
      end
    end
  end
end
