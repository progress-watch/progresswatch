# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Readme' do
  it 'quotes docker-compose.yml exactly' do
    quoted = Rails.root.join('README.md').read[/```yaml\n(.*?)```/m, 1]

    expect(quoted).to eq(Rails.root.join('docker-compose.yml').read)
  end
end
