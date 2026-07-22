class ChangeUserGroupUserIdToString < ActiveRecord::Migration[7.0]
  def change
    change_column :user_groups, :user_id, :string
  end
end
