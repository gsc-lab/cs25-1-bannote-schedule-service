class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.bigint :default_group_id, null: false
      t.string :user_number, null: false, limit: 20
      t.string :name, null: false, limit: 20
      t.string :email, null: false, limit: 50
      t.string :department, null: false, limit: 30
      t.timestamps
    end
  end
end
