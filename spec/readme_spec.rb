# frozen_string_literal: true

require 'rails_helper'

# The Docker page renders docker-compose.yml off disk, so it cannot drift. The README is
# markdown and has to hold its own copy, which is exactly the kind of second source that
# rots quietly — the last one lost the Sidekiq service and documented a server that never
# notifies anyone.
RSpec.describe 'Readme' do
  it 'quotes docker-compose.yml exactly' do
    quoted = Rails.root.join('README.md').read[/```yaml\n(.*?)```/m, 1]

    expect(quoted).to eq(Rails.root.join('docker-compose.yml').read)
  end
end
