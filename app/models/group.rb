class Group < ApplicationRecord
  belongs_to :group_permission, foreign_key: :group_permission_id
  has_many :group_tags, dependent: :destroy
  has_many :tags, through: :group_tags
  has_many :group_updates, dependent: :destroy
  has_many :user_groups, dependent: :destroy
  has_many :users, through: :user_groups

  # ============================
  #  enum 정의 (정상 구문)
  # ============================
  GROUP_TYPES = { normal: 0, department: 1, assistant: 2 }.freeze

  def group_type_name
    GROUP_TYPES.key(group_type)
  end

  def group_type_name=(value)
    self.group_type = GROUP_TYPES[value]
  end

  validates :group_name, presence: true, length: { maximum: 100 }
  validates :color_default, presence: true
  validates :is_public, inclusion: { in: [true, false] }
  validates :group_permission_id, presence: true
  validates :group_type, presence: true

  scope :active, -> { where(deleted_at: nil) }
end
