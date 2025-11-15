class CreateGroupPermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :group_permissions do |t|
      t.string :permission, null: false
      t.datetime :created_at
      t.integer :created_by
    end
  end
end


# sql
# CREATE TABLE `group_permissions`(
#   `id` bigint NOT NULL AUTO_INCREMENT PRIMARY KEY,
#   `permission` varchar(255) NOT NULL,
#   `created at` datetime DEFAULT NULL,
#   `created__by` int  DEFAULT NULL,

# ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;(한글꺠지지않도록 햐줘)
