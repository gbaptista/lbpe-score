# frozen_string_literal: true

require 'yaml'
require 'json'
require 'coderay'
require 'pp'
require 'stringio'

module LBPE
  module Logic
    module Printer
      def self.highlight(raw, as: 'json')
        CodeRay.scan(raw, as.to_sym).terminal
      end

      def self.pretty(object, as: 'ruby')
        case as
        when 'ruby'
          output = StringIO.new
          PP.pp(object, output)
          highlight(output.string, as: 'ruby')
        when 'yaml'
          highlight(YAML.dump(stringify_keys(object)).sub(/\A---\n/, ''), as: 'yaml')
        when 'json'
          highlight(JSON.pretty_generate(object, indent: '  '), as: 'json')
        else
          object.inspect
        end
      end

      def self.symbolize_keys(object)
        case object
        when Hash
          object.each_with_object({}) do |(key, value), result|
            result[key.to_sym] = symbolize_keys(value)
          end
        when Array
          object.map { |e| symbolize_keys(e) }
        else
          object
        end
      end

      def self.stringify_keys(object)
        case object
        when Hash
          object.each_with_object({}) do |(key, value), result|
            result[key.to_s] = stringify_keys(value)
          end
        when Array
          object.map { |e| stringify_keys(e) }
        else
          object
        end
      end
    end
  end
end
