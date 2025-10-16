class CreateUserGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :user_groups do |t|
      t.bigint :group_id, null: false
      t.datetime :created_at, null: false
    end
  end
end
