# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Locales' do
  def flatten_keys(hash, prefix = '')
    hash.flat_map do |key, value|
      value.is_a?(Hash) ? flatten_keys(value, "#{prefix}#{key}.") : ["#{prefix}#{key}"]
    end
  end

  def keys_for(locale)
    flatten_keys(YAML.load_file(Rails.root.join("config/locales/#{locale}.yml"))[locale.to_s])
  end

  describe 'the files' do
    it 'carries every key in every language' do
      english = keys_for(:en).sort

      Locales::NAMES.each_key do |locale|
        expect(keys_for(locale).sort).to eq(english), "#{locale}.yml does not match en.yml"
      end
    end

    it 'has a file for every language the switcher offers, and no others' do
      shipped = Rails.root.glob('config/locales/*.yml').map { |path| path.basename('.yml').to_s.to_sym }

      expect(shipped.sort).to eq(Locales::NAMES.keys.sort)
      expect(I18n.available_locales.sort).to eq(Locales::NAMES.keys.sort)
    end

    # A dropped interpolation raises at render time, on one page, in one language.
    it 'keeps the same interpolations in every language' do
      english = YAML.load_file(Rails.root.join('config/locales/en.yml'))['en']

      Locales::NAMES.each_key do |locale|
        other = YAML.load_file(Rails.root.join("config/locales/#{locale}.yml"))[locale.to_s]

        english.each do |key, value|
          next unless value.is_a?(String)

          expect(other[key].to_s.scan(/%\{(\w+)\}/).sort)
            .to eq(value.scan(/%\{(\w+)\}/).sort), "#{locale}.yml: #{key}"
        end
      end
    end

    # An interpolated lookup cannot be scanned; the parity example above covers those.
    it 'defines every key the interface asks for' do
      sources = Rails.root.glob('app/views/**/*.erb') + Rails.root.glob('app/controllers/**/*.rb') +
                Rails.root.glob('lib/**/*.rb')
      used = sources.flat_map { |path| File.read(path).scan(/\bt\(['"]([a-z][a-z0-9_]*)['"]/) }.flatten.uniq

      defined = YAML.load_file(Rails.root.join('config/locales/en.yml'))['en'].keys

      expect(used).not_to be_empty
      expect(used - defined).to be_empty
    end
  end

  describe 'resolution' do
    it 'follows the browser when nothing has been chosen' do
      get '/s/new', headers: { 'Accept-Language' => 'de-DE,de;q=0.9,en;q=0.8' }

      expect(response.body).to include('Neuer Bereich')
    end

    it 'skips a language it does not have rather than failing the request' do
      get '/s/new', headers: { 'Accept-Language' => 'uk-UA,uk;q=0.9,fr;q=0.8' }

      expect(response.body).to include('Nouvel espace')
    end

    it 'falls back to English when the header names nothing shipped, or is absent' do
      get '/s/new', headers: { 'Accept-Language' => 'uk-UA,uk;q=0.9' }
      expect(response.body).to include('New space')

      get '/s/new'
      expect(response.body).to include('New space')
    end

    it 'remembers a choice in a cookie and prefers it over the browser' do
      get '/s/new', params: { locale: 'it' }, headers: { 'Accept-Language' => 'de' }

      expect(response.cookies['locale']).to eq('it')
      expect(response.body).to include('Nuovo spazio')

      get '/s/new', headers: { 'Accept-Language' => 'de' }
      expect(response.body).to include('Nuovo spazio')
    end

    it 'ignores a locale it does not have in the parameter, and remembers nothing' do
      get '/s/new', params: { locale: 'klingon' }, headers: { 'Accept-Language' => 'de' }

      expect(response.cookies['locale']).to be_nil
      expect(response.body).to include('Neuer Bereich')
    end

    it 'names the language on the html element' do
      get '/', headers: { 'Accept-Language' => 'pt' }

      expect(response.body).to include('<html lang="pt"')
    end
  end

  describe 'what is translated' do
    let(:space) { Spaces::Create.call(title: 'Backups') }
    let(:frame_request) { { 'Turbo-Frame' => 'finished' } }

    it 'renders the dashboard and its task labels in the chosen language' do
      task = Tasks::Create.call(space:, title: 'Nightly')
      Tasks::Report.call(task, current: 1, end_value: 1)

      get "/s/#{space.uuid}/tasks", params: { state: 'finished', locale: 'fr' }, headers: frame_request

      expect(response.body).to include('terminée en')
    end

    it 'heads the history with the month in that language' do
      task = Tasks::Create.call(space:, title: 'Nightly')
      task.update!(created_at: Time.utc(2026, 3, 4), finished_at: Time.utc(2026, 3, 4), duration: 3)

      get "/s/#{space.uuid}/tasks", params: { state: 'finished', locale: 'de' }, headers: frame_request

      expect(response.body).to include('März 2026')
    end

    # rescue_from is handled outside the callback chain, so the not-found page renders
    # after around_action has already put the locale back. It has to ask again.
    it 'translates the page for a space that does not exist' do
      get '/s/00000000-0000-0000-0000-000000000000', params: { locale: 'es' }

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include('No existe ese espacio')
    end

    it 'hands the browser a dictionary of the strings it interpolates itself' do
      get '/', params: { locale: 'nl' }

      dictionary = JSON.parse(CGI.unescapeHTML(response.body[/<space-list[^>]*data-i18n="([^"]*)"/, 1]))

      # rubocop:disable Style/FormatStringToken
      expect(dictionary['remove_what_from_this_device']).to start_with('%{what} van dit apparaat verwijderen?')
      expect(dictionary['opened_count_m_ago']).to eq('%{count} min geleden geopend')
      # rubocop:enable Style/FormatStringToken
      expect(dictionary.keys).to include('this_space', 'never_opened', 'opened_just_now')
    end

    it 'translates the documentation, snippet labels and all' do
      get '/docs/curl', params: { locale: 'de' }

      expect(response.body).to include('Die API mit curl ausprobieren')
      expect(response.body).to include('Legen Sie eine Aufgabe an, behalten Sie ihre UUID.')
    end

    it 'translates a whole prose document, paragraph by paragraph' do
      get '/docs/self-hosting', params: { locale: 'it' }

      expect(response.body).to include('Il server è open source sotto licenza AGPL')
      expect(response.body).to include('bin/rails sweep_empty_spaces')
      expect(response.body).to include('Perché la 7979')
    end

    it 'renders the reference tables in the chosen language, with the names untouched' do
      get '/docs/environment-variables', params: { locale: 'nl' }

      expect(response.body).to include('>Standaard</th>')
      expect(response.body).to include('>SECRET_KEY_BASE</code>')
      expect(response.body).to include('class="prose')
    end

    # A /de/ copy would differ from this page in the navbar and nothing else.
    it 'gives the API reference one URL and no language versions' do
      get '/docs/api', params: { locale: 'de' }

      expect(response.body).to include('A write replaces the whole state')
      expect(response.body).to include('>Doku</a>')
      expect(response.body).not_to include('hreflang')

      get '/de/docs/api'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'being found' do
    # Indexing belongs to the hosted deployment; nothing on somebody's own box opts in.
    before { allow(ProgressWatch).to receive(:multitenant?).and_return(true) }

    it 'canonicalises an indexable page to the language it rendered' do
      get '/fr/docs'

      expect(response.body).to include('<link rel="canonical" href="http://www.example.com/fr/docs">')
      expect(response.body).to include('<link rel="alternate" hreflang="de" href="http://www.example.com/de/docs">')
      expect(response.body).to include('<link rel="alternate" hreflang="en" href="http://www.example.com/docs">')
      expect(response.body).to include('<link rel="alternate" hreflang="x-default" href="http://www.example.com/docs">')
    end

    it 'drops the parameter from English, so the default keeps a clean URL' do
      get '/docs'

      expect(response.body).to include('<link rel="canonical" href="http://www.example.com/docs">')
    end

    it 'says nothing about alternates on a page nobody may index' do
      space = Spaces::Create.call(title: 'Backups')

      get "/s/#{space.uuid}", params: { locale: 'fr' }

      expect(response.body).to include('noindex')
      expect(response.body).not_to include('hreflang')
    end
  end

  describe 'the switcher' do
    # /en/docs/agent is not a route, and a bare /docs/agent would render English without
    # recording that anyone asked for it — leaving the cookie on the language before.
    it 'sends English to the bare path with the choice in the query' do
      get '/de/docs/agent'

      expect(response.body).to include('href="/docs/agent?locale=en"')
      expect(response.body).not_to include('/en/docs')
    end

    it 'switches back to English from any page, and remembers it' do
      space = Spaces::Create.call(title: 'Backups')

      get "/s/#{space.uuid}", params: { locale: 'de' }
      expect(response.body).to include('Entfernt diesen Bereich')

      get "/s/#{space.uuid}", params: { locale: 'en' }
      expect(response.cookies['locale']).to eq('en')

      get "/s/#{space.uuid}"
      expect(response.body).to include('Removes this space from this device only')
    end

    it 'remembers English chosen while reading the documentation' do
      get '/de/docs/agent'
      expect(response.cookies['locale']).to eq('de')

      get '/docs/agent', params: { locale: 'en' }
      expect(response.cookies['locale']).to eq('en')
      expect(response.body).to include('Give an AI agent a progress skill')
    end

    it 'offers every language once, marking the one in use' do
      get '/', params: { locale: 'it' }

      expect(response.body.scan('aria-label="Lingua"').size).to eq(1)
      Locales::NAMES.each_value { |name| expect(response.body).to include(">#{name}</a>") }
      expect(response.body).to match(%r{<a[^>]*aria-current="true"[^>]*>Italiano</a>})
    end

    it 'keeps the query a page was already carrying' do
      get '/docs/curl', params: { space: 'a-space' }

      expect(response.body).to include('/de/docs/curl?space=a-space')
    end

    it 'falls back to the parameter on a page with no segment for the language' do
      space = Spaces::Create.call(title: 'Backups')

      get "/s/#{space.uuid}"

      expect(response.body).to include("/s/#{space.uuid}?locale=de")
    end
  end

  describe 'the documentation path' do
    it 'serves each language from its own prefix' do
      get '/de/docs/agent'
      expect(response.body).to include('Einem KI-Agenten einen Fortschritts-Skill geben')

      get '/es/docs/agent'
      expect(response.body).to include('Dar a un agente de IA un skill de progreso')
    end

    # A page whose canonical and hreflang both call it English may not render German
    # because of a header nobody can see.
    it 'ignores the browser and the cookie once the path carries a language' do
      allow(ProgressWatch).to receive(:multitenant?).and_return(true)

      get '/docs', headers: { 'Accept-Language' => 'de-DE,de;q=0.9' }

      expect(response.body).to include('Watch any process')
      expect(response.body).to include('<link rel="canonical" href="http://www.example.com/docs">')

      get '/docs', params: { locale: 'de' }
      get '/docs'
      expect(response.body).to include('Watch any process')
    end

    # The docs stopped asking the cookie, so a link into them has to spell the language
    # out or a reader who chose German lands back in English.
    it 'carries the chosen language into the docs from outside them' do
      space = Spaces::Create.call(title: 'Backups')

      get "/s/#{space.uuid}", params: { locale: 'de' }

      expect(response.body).to include('href="/de/docs"')
      expect(response.body).to include("/de/docs/cli?space=#{space.uuid}")
    end

    it 'leaves English at the bare path and routes no /en' do
      get '/docs/agent'
      expect(response.body).to include('Give an AI agent a progress skill')

      get '/en/docs/agent'
      expect(response).to have_http_status(:not_found)
    end

    # Without this the prefix would survive exactly one click.
    it 'keeps the prefix on every link out of a translated page' do
      get '/de/docs/agent'

      expect(response.body).to include('href="/de/docs/cli"')
      expect(response.body).to include('href="/de/docs"')
    end

    # The share modal turns this URL into a QR code, so a stray parameter would be
    # scanned into somebody's phone.
    it 'never puts a language in a space URL' do
      space = Spaces::Create.call(title: 'Backups')

      get "/s/#{space.uuid}/link", params: { locale: 'de' }

      expect(response.body).to include(%(value="http://www.example.com/s/#{space.uuid}"))
      expect(response.body).not_to include("/s/#{space.uuid}?locale")
    end
  end
end
