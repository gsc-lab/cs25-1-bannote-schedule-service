class CreateGroupPermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :group_permissions do |t|
      t.string :permission, null: false
      t.datetime :created_at
      t.integer :created_by
    end
  end
end
