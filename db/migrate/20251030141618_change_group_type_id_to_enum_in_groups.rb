class ChangeGroupTypeIdToEnumInGroups < ActiveRecord::Migration[8.0]
  def change
    # Change the column type to integer for enum
    change_column :groups, :group_type, :integer, default: 1, null: false
  end
end