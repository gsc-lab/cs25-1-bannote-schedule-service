class AddScheduleCodeToSchedules < ActiveRecord::Migration[8.0]
  def change
    add_column :schedules, :schedule_code, :string
  end
end


# sql
# CREATE TABLE `groups`(
#   `id` bigint NOT NULL AUTO_INCREMENT PRIMARY KEY,
#   `groud_type_id` bigint NOT NULL,
#   `department_id` bigint,
#   `group_name` varchar(100) NOT NULL,
#   `group_description` varchar(500),
#   `is_public` tinyint(1) DEFAULT  1,
#   `is_published` tinyint(1) DEFAULT 1,
#   `color_default` varchar(10),
#   `color_highlight` varchar(10),
#   `created_by` int,
#   `created_at` datetime(6) NOT NULL,
#   `update_at` datetime(6) NOT NULL
# );
