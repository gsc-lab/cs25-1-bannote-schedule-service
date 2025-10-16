class CreateSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :schedules do |t|
      t.bigint :group_id, null: false
      t.bigint :schedule_link_id, null: false
      t.string :memo, limit: 255, null: true
      t.string :color, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: true
      t.datetime :deleted_at, null: true
      t.integer :created_by, null: false
      t.integer :updated_by, null: true
      t.integer :deleted_by, null: true
    end

    add_index :schedules, :schedule_link_id
  end
end
