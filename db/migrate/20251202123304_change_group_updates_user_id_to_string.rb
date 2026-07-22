class ChangeGroupUpdatesUserIdToString < ActiveRecord::Migration[7.1]
  def change
    change_column :group_updates, :user_id, :string
  end
end
