class CreateScheduleFiles < ActiveRecord::Migration[8.0]
  def change
    create_table :schedule_files do |t|
      t.bigint :schedule_link_id, null: false
      t.integer :created_by, null: false
      t.string :file_path, null: false

      t.timestamps  # created_at, updated_at 자동 생성
    end

    add_index :schedule_files, :schedule_link_id
  end
end
