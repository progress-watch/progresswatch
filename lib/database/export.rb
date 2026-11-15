# frozen_string_literal: true

module Database
  module Export
    module_function

    def call(io)
      scopes.each_with_object(Hash.new(0)) do |scope, counts|
        scope.find_each do |record|
          io.puts(JSON.generate(table: scope.table_name, row: serialize(record)))
          counts[scope.table_name] += 1
        end
      end
    end

    def scopes
      [Space.all, Task.where(parent_uuid: nil), Task.where.not(parent_uuid: nil), PushSubscription.all]
    end

    def serialize(record)
      record.attributes.sort.to_h.transform_values do |value|
        value.respond_to?(:iso8601) ? value.utc.iso8601(6) : value
      end
    end
  end
end
