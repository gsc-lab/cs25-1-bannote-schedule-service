class CreateGroupTags < ActiveRecord::Migration[8.0]
  def change
    create_table :group_tags do |t|
      t.bigint :group_id, null: false
      t.bigint :tag_id, null: false
    end
  end
end
