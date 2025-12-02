class ChangeUserIdToStringInUserGroups < ActiveRecord::Migration[6.1]
  def change
    change_column :user_groups, :user_id, :string
  end
end
