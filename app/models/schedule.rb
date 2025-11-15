class Schedule < ApplicationRecord
  belongs_to :group
  belongs_to :schedule_link, foreign_key: "schedule_link_id", optional:true

  validates :color, presence: true
  validates :created_by, presence: true

  scope :active, -> { where(deleted_at: nil) }
end
