# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OpenApi::CodeSamples do
  it 'has samples for every operation the reference shows' do
    expect(described_class::SAMPLES.keys).to match_array(OpenApi::Operations.call.pluck(:id))
  end

  it 'writes every operation in every language that can express it' do
    described_class::SAMPLES.each do |id, samples|
      expect(samples.keys - described_class::LANGUAGES.keys).to be_empty, id
      expect(samples.values).to all(be_present), id
      expect(samples.keys).to include('curl'), id

      next if described_class::URL_ONLY.include?(id)

      expect(samples.keys).to include(*described_class::HTTP_LANGUAGES), id
    end
  end

  it 'names the host and every fixed segment of the path the document defines' do
    OpenApi::Operations.call.each do |operation|
      samples = described_class.call(operation, base_url: 'https://progress.watch')
      segments = operation[:path].split('/').reject { |segment| segment.empty? || segment.start_with?('{') }

      samples.slice(*described_class::HTTP_LANGUAGES).each do |language, code|
        expect(code).to include('https://progress.watch', *segments), "#{operation[:id]} in #{language}"
      end
    end
  end

  it 'spells a path parameter the way each language spells a variable' do
    samples = described_class.call(OpenApi::Operations.call.find { |o| o[:id] == 'get-space' },
                                   base_url: 'https://progress.watch')

    expect(samples['curl']).to include('/spaces/$SPACE_UUID')
    expect(samples['javascript']).to include('/spaces/${spaceUuid}')
    expect(samples['python']).to include('f"https://progress.watch/spaces/{space_uuid}"')
    expect(samples['php']).to include('/spaces/{$spaceUuid}')
    expect(samples['ruby']).to include("/spaces/\#{space_uuid}")
    expect(samples['csharp']).to include('$"/spaces/{spaceUuid}"')
  end

  it 'puts the tabs in the order LANGUAGES gives, whatever order the samples are in' do
    samples = { 'cli' => 'x', 'javascript' => 'y', 'python' => 'z' }

    expect(described_class.tabs(samples).keys).to eq(%w[javascript python cli])
  end

  it 'offers no tabs at all when an operation has no samples' do
    expect(described_class.tabs({})).to be_empty
  end

  describe 'the lifecycle block' do
    it 'covers every language the switcher offers' do
      expect(described_class::LIFECYCLE.keys).to match_array(described_class::LANGUAGES.keys)
    end

    it 'walks create, report and close, in that order' do
      samples = described_class.lifecycle(base_url: 'https://progress.watch')

      described_class::HTTP_LANGUAGES.each do |language|
        code = samples.fetch(language)

        expect(code).to include('/spaces'), language
        expect(code.index('/spaces')).to be < code.index('/tasks'), language
        expect(code.index('/tasks')).to be < code.rindex('done'), language
      end
    end

    it 'closes with a bare done' do
      described_class.lifecycle(base_url: 'https://progress.watch').each do |language, code|
        expect(code.lines.last).not_to include('current'), language
      end
    end
  end
end
