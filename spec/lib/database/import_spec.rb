# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Database::Import do
  let(:models) { [Space, Task, PushSubscription] }

  def snapshot
    models.to_h { |model| [model.table_name, model.order(:uuid).map(&:attributes)] }
  end

  def export
    StringIO.new.tap { |io| Database::Export.call(io) }.tap(&:rewind)
  end

  def seed
    space = create_space(title: 'Crawlers 🕷')
    space.update!(icon: '🕷', created_at: Time.utc(2026, 8, 3, 9, 15, 42, 123_456))
    parent = create_task(space, title: 'Nightly crawl', source: 'crawler.py')
    child = create_task(space, title: 'Fetch sitemap', parent_uuid: parent.uuid)
    child.update!(finished_at: Time.utc(2026, 8, 3, 9, 20, 1, 654_321), duration: 259)
    PushSubscription.create!(space: space, endpoint: 'https://push.example/abc', p256dh: 'key', auth: 'secret',
                             endpoint_digest: PushSubscription.digest('https://push.example/abc'))
  end

  def clear
    PushSubscription.delete_all
    Task.where.not(parent_uuid: nil).delete_all
    Task.delete_all
    Space.delete_all
  end

  it 'covers every table in the schema' do
    tables = ApplicationRecord.connection.tables - %w[schema_migrations ar_internal_metadata]

    expect(described_class::MODELS.keys).to match_array(tables)
    expect(Database::Export.scopes.map(&:table_name).uniq).to match_array(tables)
  end

  it 'brings back exactly what was exported, to the microsecond' do
    seed
    before = snapshot
    dump = export
    clear

    expect(described_class.call(dump)).to eq('spaces' => 1, 'tasks' => 2, 'push_subscriptions' => 1)
    expect(snapshot).to eq(before)
  end

  it 'writes a child after its parent, whatever their uuids' do
    space = create_space
    parent = create_task(space)
    parent.update_columns(uuid: 'ffffffff-ffff-4fff-8fff-ffffffffffff')
    Task.insert_all([{ uuid: '00000000-0000-4000-8000-000000000000', space_uuid: space.uuid,
                       parent_uuid: parent.uuid, created_at: Time.current }])

    tasks = export.each_line.map { |line| JSON.parse(line) }.select { |entry| entry['table'] == 'tasks' }
    uuids = tasks.map { |entry| entry['row']['uuid'] }

    expect(uuids).to eq(%w[ffffffff-ffff-4fff-8fff-ffffffffffff 00000000-0000-4000-8000-000000000000])
  end

  it 'writes the columns of a row in one order on either adapter' do
    seed

    rows = export.each_line.map { |line| JSON.parse(line)['row'].keys }

    expect(rows).to all(satisfy { |keys| keys == keys.sort })
  end

  it 'skips rows that are already here and counts only what it wrote' do
    seed
    dump = export
    Task.where.not(parent_uuid: nil).delete_all

    expect(described_class.call(dump)).to eq('spaces' => 0, 'tasks' => 1, 'push_subscriptions' => 0)
    expect(Task.count).to eq(2)
  end

  it 'writes nothing when a row cannot go in' do
    seed
    lines = export.readlines
    clear
    orphan = JSON.parse(lines.last)
    orphan['row'].merge!('uuid' => SecureRandom.uuid, 'space_uuid' => SecureRandom.uuid)

    expect { described_class.call(StringIO.new((lines + [JSON.generate(orphan)]).join)) }
      .to raise_error(ActiveRecord::InvalidForeignKey)
    expect(Space.count).to eq(0)
  end
end
