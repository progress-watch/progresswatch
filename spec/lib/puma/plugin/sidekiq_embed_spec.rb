# frozen_string_literal: true

require 'rails_helper'
require 'puma/launcher'
require Rails.root.join('lib/puma/plugin/sidekiq_embed')

RSpec.describe 'SidekiqEmbed' do
  def run_in_trap
    outcome = nil
    previous = Signal.trap('USR2') do
      yield
      outcome = :stopped
    rescue ThreadError => e
      outcome = e.message
    end

    Process.kill('USR2', Process.pid)
    sleep 0.01 while outcome.nil?
    outcome
  ensure
    Signal.trap('USR2', previous)
  end

  it 'stops Sidekiq from inside the SIGTERM trap, where Puma fires after_stopped' do
    events = Puma::Events.new
    plugin = Puma::Plugins.find('sidekiq_embed').new
    plugin.start(instance_double(Puma::Launcher, events:))
    sidekiq = Class.new do
      attr_reader :stopped

      def stop = Mutex.new.synchronize { @stopped = true }
    end.new
    plugin.instance_variable_set(:@sidekiq, sidekiq)

    expect(run_in_trap { events.fire_after_stopped! }).to eq(:stopped)
    expect(sidekiq.stopped).to be(true)
  end
end
