# frozen_string_literal: true

class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks, id: false do |t|
      t.string :uuid, limit: 36, null: false, primary_key: true
      t.string :space_uuid, limit: 36, null: false
      t.string :parent_uuid, limit: 36
      t.string :title
      t.string :source
      t.datetime :created_at, null: false
      t.datetime :finished_at
      t.integer :duration
    end

    add_index :tasks, :space_uuid
    add_index :tasks, :parent_uuid

    add_foreign_key :tasks, :spaces, column: :space_uuid, primary_key: :uuid
    add_foreign_key :tasks, :tasks, column: :parent_uuid, primary_key: :uuid
  end
end
