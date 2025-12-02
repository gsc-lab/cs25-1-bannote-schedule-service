class ChangeUserNumberToString < ActiveRecord::Migration[7.0]
  def up
    change_column :users, :user_number, :string
  end

  def down
    change_column :users, :user_number, :integer
  end
end
