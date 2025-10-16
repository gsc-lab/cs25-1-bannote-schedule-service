class CreateGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :groups do |t|
      t.bigint :group_type_id, null: false
      t.bigint :department_id, null: true
      t.string :group_name, null: false, limit: 100
      t.string :group_description, limit: 500
      t.boolean :is_public, null: false
      t.string :color_default, null: false, limit: 10
      t.string :color_highlight, null: false, limit: 10
      t.boolean :is_published, null: false
      t.datetime :deleted_at, null: true
      t.integer :created_by, null: true
      t.integer :updated_by, null: true
      t.integer :deleted_by, null: true

      t.timestamps  # created_at, updated_at 자동 생성
    end
  end
end
