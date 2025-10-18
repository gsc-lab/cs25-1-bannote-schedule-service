class AddGroupCodeToGroups < ActiveRecord::Migration[8.0]
  def change
    add_column :groups, :group_code, :string
  end
end
