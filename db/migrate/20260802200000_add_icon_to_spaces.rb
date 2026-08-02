# frozen_string_literal: true

class AddIconToSpaces < ActiveRecord::Migration[8.1]
  def change
    add_column :spaces, :icon, :string, limit: 16
  end
end
