class RenameGroupTypeIdToGroupTypeInGroups < ActiveRecord::Migration[8.0]
  def change
    rename_column :groups, :group_type_id, :group_type
  end
end
