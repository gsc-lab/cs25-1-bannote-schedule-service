class CreateGroupUpdates < ActiveRecord::Migration[8.0]
  def change
    create_table :group_updates do |t|
      t.bigint :group_id, null: false
      t.datetime :created_at, null: false
    end
  end
end
