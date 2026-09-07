# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'EagerLoading' do
  it 'resolves every constant Zeitwerk expects from a path' do
    expect { Rails.application.eager_load! }.not_to raise_error
  end
end
