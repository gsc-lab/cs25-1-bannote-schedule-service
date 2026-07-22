class CreateDepartments < ActiveRecord::Migration[7.0]
  def change
    create_table :departments, id: false do |t|
      t.string :department_code, null: false, primary_key: true
      t.string :department_name, null: false
      t.timestamps
    end

    add_index :departments, :department_code, unique: true
  end
end
