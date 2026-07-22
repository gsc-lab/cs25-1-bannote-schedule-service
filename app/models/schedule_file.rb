class ScheduleFile < ApplicationRecord
  belongs_to :schedule_link

  validates :file_path, presence: true
  validates :created_by, presence: true
end
