class ScheduleLink < ApplicationRecord
  has_many :schedules, dependent: :destroy
  has_many :schedule_files, dependent: :destroy

  validates :title, presence: true, length: { maximum: 100 }
  validates :start_time, :end_time, presence: true
end
