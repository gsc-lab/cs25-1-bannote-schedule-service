class Schedule < ApplicationRecord
  belongs_to :group
  belongs_to :schedule_link, dependent: :destroy

  validates :color, presence: true
  validates :created_by, presence: true

  # 삭제되지 않은 일정만 기본 조회
  scope :active, -> { where(deleted_at: nil) }
end