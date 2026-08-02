# frozen_string_literal: true

class CreateSpaces < ActiveRecord::Migration[8.1]
  def change
    create_table :spaces, id: false do |t|
      t.string :uuid, limit: 36, null: false, primary_key: true
      t.string :title
      t.datetime :created_at, null: false
    end
  end
end
