# frozen_string_literal: true

require 'rails_helper'

# The samples are written by hand rather than generated, so what rots is coverage: an
# endpoint added to the document and forgotten here, or a path that moved and left the
# snippets calling the old one.
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

  # The CLI is not a transport: `progresswatch list` reads a space without naming a URL,
  # so only the HTTP languages can be checked against the document. Segments rather than
  # the whole URL, because several of them configure a base_uri once and then pass a
  # relative path, which is the idiomatic shape in those libraries.
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

  # The page's opening block. It is the one sample that is not an operation, so nothing
  # else checks it — and a language missing from it silently falls back to another tab.
  describe 'the lifecycle block' do
    it 'covers every language the switcher offers' do
      expect(described_class::LIFECYCLE.keys).to match_array(described_class::LANGUAGES.keys)
    end

    # Paths only for the transports: the CLI names no URL, which is the same reason
    # HTTP_LANGUAGES exists for the per-operation samples.
    it 'walks create, report and close, in that order' do
      samples = described_class.lifecycle(base_url: 'https://progress.watch')

      described_class::HTTP_LANGUAGES.each do |language|
        code = samples.fetch(language)

        expect(code).to include('/spaces'), language
        expect(code.index('/spaces')).to be < code.index('/tasks'), language
        expect(code.index('/tasks')).to be < code.rindex('done'), language
      end
    end

    # It closes with done and nothing else, which is what keeps the last counts. Repeating
    # current here would teach the workaround for a bug that no longer exists.
    it 'closes with a bare done' do
      described_class.lifecycle(base_url: 'https://progress.watch').each do |language, code|
        expect(code.lines.last).not_to include('current'), language
      end
    end
  end
end
