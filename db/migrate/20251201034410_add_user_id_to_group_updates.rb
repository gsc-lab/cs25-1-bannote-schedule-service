class AddUserIdToGroupUpdates < ActiveRecord::Migration[8.0]
  def change
    add_column :group_updates, :user_id, :bigint, null: false
    add_index :group_updates, :user_id
  end
end
