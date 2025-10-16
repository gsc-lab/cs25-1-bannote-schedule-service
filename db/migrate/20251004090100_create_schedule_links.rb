class CreateScheduleLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :schedule_links do |t|
      t.string :title, null: false, limit: 100
      t.integer :place_id
      t.string :place_text, limit: 20
      t.text :description
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.boolean :is_allday, null: false, default: false
      t.integer :created_by

      t.timestamps  # created_at, updated_at 자동 생성
    end
  end
end
