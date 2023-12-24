# frozen_string_literal: true

require 'nano-bots'

module LBPE
  META = {
    project: 'LBPE Score',
    version: '0.0.1',
    'nano-bots': { version: NanoBot.version, specification: NanoBot.specification },
    github: 'https://github.com/gbaptista/lbpe-score'
  }.freeze
end
