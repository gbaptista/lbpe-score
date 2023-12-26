# frozen_string_literal: true

require_relative '../../src/logic/identifier'

RSpec.describe LBPE::Logic::Identifier do
  it 'symbolizes keys' do
    expect(described_class.delete_exact_path(
             {
               j: { meta: { title: 'a' } },
               meta: { tile: { info: 'b' }, other: 'c' },
               a: 3,
               c: { d: 4, e: 'd' }
             },
             %i[meta tile info]
           )).to eq({ a: 3, c: { d: 4, e: 'd' },
                      j: { meta: { title: 'a' } },
                      meta: { other: 'c', tile: {} } })

    expect(described_class.cartridge('spec/data/cartridge-a.yml')).to eq(
      'b4a8800b9b2743c83176b6b3afc156fe0311e535e17061fd9262b66604a5d64c'
    )

    expect(described_class.cartridge('spec/data/cartridge-b.yml')).to eq(
      'b4a8800b9b2743c83176b6b3afc156fe0311e535e17061fd9262b66604a5d64c'
    )

    expect(described_class.cartridge('spec/data/cartridge-c.yml')).to eq(
      '611fd3663aeebfe44e6b0bd2cdee314efb1295971bdf3423546baa825a19d215'
    )

    expect(described_class.cartridge('spec/data/cartridge-d.yml')).to eq(
      '60819c82250df26bdf6eace72d6cc9dad89af111300e254074ebc7579c7ee7fc'
    )
  end
end
