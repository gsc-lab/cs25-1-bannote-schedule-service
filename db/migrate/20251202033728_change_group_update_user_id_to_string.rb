class ChangeGroupUpdateUserIdToString < ActiveRecord::Migration[7.0]
  def change
    change_column :group_updates, :user_id, :string
  end
end
