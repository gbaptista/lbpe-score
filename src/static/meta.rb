# frozen_string_literal: true

require 'nano-bots'

module LBPE
  META = {
    project: 'LBPE Score',
    version: '1.0.0',
    'nano-bots': { version: NanoBot.version, specification: NanoBot.specification },
    github: 'https://github.com/gbaptista/lbpe-score',
    report: {
      version: '1.0.0',
      url: 'https://gbaptista.github.io/lbpe-score/',
      data: 'https://github.com/gbaptista/lbpe-score-data'
    }
  }.freeze
end
