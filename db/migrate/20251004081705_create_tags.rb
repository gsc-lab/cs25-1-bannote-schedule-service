class CreateTags < ActiveRecord::Migration[8.0]
  def change
    create_table :tags do |t|
      t.string :name, null: false, limit: 50
      t.datetime :created_at, null: false
      t.integer :created_by, null: false
    end
  end
end
