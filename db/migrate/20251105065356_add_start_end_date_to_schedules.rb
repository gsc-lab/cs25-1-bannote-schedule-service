class AddStartEndDateToSchedules < ActiveRecord::Migration[8.0]
  def change
    add_column :schedules, :start_date, :datetime
    add_column :schedules, :end_date, :datetime
  end
end
