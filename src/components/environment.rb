# frozen_string_literal: true

require 'nano-bots'
require 'rbconfig'

module LBPE
  module Components
    module Environment
      def self.details
        {
          system: {
            os: RbConfig::CONFIG['host_os'],
            cpu: RbConfig::CONFIG['host_cpu']
          },
          ruby: {
            version: RUBY_VERSION,
            platform: RUBY_PLATFORM,
            patch: RUBY_PATCHLEVEL
          },
          'nano-bots': {
            version: NanoBot.version,
            specification: NanoBot.specification
          }
        }
      end
    end
  end
end
