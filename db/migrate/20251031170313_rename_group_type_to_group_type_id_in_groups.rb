class RenameGroupTypeToGroupTypeIdInGroups < ActiveRecord::Migration[8.0]
  def change
    rename_column :groups, :group_type, :group_type_id
  end
end
