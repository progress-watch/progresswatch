# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Native app' do
  let(:app_headers) { { 'User-Agent' => 'Progress Watch iOS/0.0.1 Hotwire Native iOS; Turbo Native iOS;' } }
  let(:space) { Spaces::Create.call(title: 'Backups') }

  def path_configuration
    JSON.parse(response.body[%r{<script type="application/json" id="native_path_configuration">(.*?)</script>}m, 1])
  end

  describe 'a browser' do
    it 'gets the web navbar, no path configuration and native actions that take no space' do
      get "/s/#{space.uuid}"

      expect(response.body).to include('<header')
      expect(response.body).not_to include('native_path_configuration')
      expect(response.body).not_to include('native-action { display: none')
      expect(response.body).to include('<title>Backups | Progress Watch</title>')
    end

    it 'keeps the round share and forget buttons on a card' do
      get '/'

      expect(response.body).not_to include('<native-menu')
      expect(response.body).to include('md:group-hover:flex')
    end
  end

  describe 'the app' do
    it 'gets no web navbar, and hides what it redraws natively' do
      get "/s/#{space.uuid}", headers: app_headers

      expect(response.body).not_to include('<header')
      expect(response.body).to include('native-action { display: none !important; }')
      expect(response.body).to include('<title>Backups</title>')
    end

    it 'is told how to route, in the language of the request' do
      get '/', headers: app_headers.merge('Accept-Language' => 'de')

      rules = path_configuration['rules']

      expect(path_configuration.dig('settings', 'strings', 'change_server')).to eq('Server wechseln')
      expect(rules.find { |rule| rule['patterns'] == ['^/$'] }.dig('properties', 'native_title')).to eq('Bereiche')
      expect(rules.find { |rule| rule['patterns'].include?('^/s/new$') }['properties'])
        .to eq('context' => 'modal', 'modal_style' => 'medium')
    end

    it 'routes every modal route as a sheet, so none opens as a pushed page' do
      get '/', headers: app_headers

      modal_patterns = path_configuration['rules'].select { |rule| rule.dig('properties', 'context') == 'modal' }
                                                  .flat_map { |rule| rule['patterns'] }

      ['/s/new', "/s/#{space.uuid}/edit", "/s/#{space.uuid}/link"].each do |path|
        expect(modal_patterns.any? { |pattern| path.match?(Regexp.new(pattern)) }).to be(true), "#{path} is not a sheet"
      end
    end

    it 'declares the space page actions for the navigation bar and its menu' do
      get "/s/#{space.uuid}", headers: app_headers

      expect(response.body).to include('data-placement="bar" data-icon="share"')
      expect(response.body).to include('data-placement="menu" data-icon="pencil"')
      expect(response.body).to include('data-icon="trash" data-label="Forget this space" data-destructive="true"')
      expect(response.body.scan('data-menu="Connect"').size).to eq(ConnectSnippets::SECTIONS.size)
    end

    it 'offers New space from the list alone, as a native button and not as a card' do
      get '/'
      expect(response.body).to include('<template data-template="add">')

      get '/', headers: app_headers
      expect(response.body).to include('data-placement="create"')
      expect(response.body).not_to include('<template data-template="add">')

      get "/s/#{space.uuid}", headers: app_headers
      expect(response.body).not_to include('data-placement="create"')
    end

    it 'moves what the web navbar holds into the list menu: backup, theme and language' do
      get '/', headers: app_headers.merge('Accept-Language' => 'fr')

      expect(response.body).to include('data-action="click:space-backup#export"')
      expect(response.body).to include('accept="application/json" data-action="change:space-backup#import"')
      expect(response.body.scan('data-action="click:theme-toggle#select"').size).to eq(3)
      expect(response.body.scan('data-menu="Langue"').size).to eq(Locales::NAMES.size)
      expect(response.body).to match(%r{data-selected="true">\s*<a href="/\?locale=fr">Français</a>})
      expect(response.body).not_to include('<details')
    end

    it 'turns the card buttons into one native menu' do
      get '/', headers: app_headers

      expect(response.body).to include('<native-menu')
      expect(response.body).to include('data-forget data-action="click:space-list#forgetSpace"')
      expect(response.body).not_to include('md:group-hover:flex')
    end

    it 'titles a documentation page with its sidebar label, which fits a navigation bar' do
      get '/docs/agent'
      expect(response.body).to include('<title>Give an AI agent a progress skill | Progress Watch</title>')

      { '/docs' => 'Get started', '/docs/agent' => 'Agent skill', '/de/docs/self-hosting' => 'Selbst hosten',
        '/docs/environment-variables' => 'Environment variables', '/docs/api' => 'API Reference' }.each do |path, title|
        get path, headers: app_headers

        expect(response.body).to include("<title>#{title}</title>"), "#{path} is not titled #{title}"
      end
    end

    it 'renders a modal route as a sheet: no heading of its own, the title in <title>' do
      get '/s/new', headers: app_headers

      expect(response.body).to include('<native-modal')
      expect(response.body).to include('<title>New space</title>')
      expect(response.body).not_to include('<h1')
    end
  end
end
