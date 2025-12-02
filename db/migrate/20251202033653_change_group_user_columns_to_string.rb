class ChangeGroupUserColumnsToString < ActiveRecord::Migration[7.0]
  def change
    change_column :groups, :created_by, :string
    change_column :groups, :updated_by, :string
    change_column :groups, :deleted_by, :string
  end
end
