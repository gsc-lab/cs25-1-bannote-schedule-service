class AddUserIdToUserGroups < ActiveRecord::Migration[8.0]
  def change
    add_column :user_groups, :user_id, :bigint
  end
end
