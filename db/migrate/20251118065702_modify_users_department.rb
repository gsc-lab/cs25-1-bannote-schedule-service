class ModifyUsersDepartment < ActiveRecord::Migration[8.0]
  def change

    remove_column :users, :department, :string if column_exists?(:users, :department)

    add_column :users, :department_code, :string unless column_exists?(:users, :department_code)
  end
end
