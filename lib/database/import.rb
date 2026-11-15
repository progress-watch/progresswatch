# frozen_string_literal: true

module Database
  module Import
    MODELS = [Space, Task, PushSubscription].index_by(&:table_name).freeze
    BATCH_SIZE = 1000

    module_function

    def call(io)
      counts = Hash.new(0)

      ApplicationRecord.transaction do
        io.each_line.each_slice(BATCH_SIZE) do |lines|
          lines.map { |line| JSON.parse(line) }.group_by { |entry| entry.fetch('table') }.each do |table, entries|
            counts[table] += MODELS.fetch(table).insert_all(entries.pluck('row')).length
          end
        end
      end

      counts
    end
  end
end
