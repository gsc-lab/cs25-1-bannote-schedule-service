class ChangeScheduleLinkIdNullable < ActiveRecord::Migration[7.0]
  def change
    change_column_null :schedules, :schedule_link_id, true
  end
end
