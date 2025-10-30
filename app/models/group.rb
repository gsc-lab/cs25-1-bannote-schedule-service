class Group < ApplicationRecord
  # ============================
  # 1. 관계 정의
  # ============================
  belongs_to :group_permission, foreign_key: :group_permission_id
  has_many :group_tags, dependent: :destroy
  has_many :tags, through: :group_tags
  has_many :group_updates, dependent: :destroy
  has_many :user_groups, dependent: :destroy
  has_many :users, through: :user_groups

  # ============================
  # 2. enum 정의 (그룹 분류용)
  # ============================
  GROUP_TYPES = { normal: 0, department: 1, assistant: 2 }.freeze

  def group_type_name
    GROUP_TYPES.key(group_type)
  end

  def group_type_name=(value)
    self.group_type = GROUP_TYPES[value]
  end

  # ============================
  # 3. 유효성 검사
  # ============================
  validates :group_name, presence: true, length: { maximum: 100 }
  validates :color_default, presence: true
  validates :is_public, inclusion: { in: [true, false] }
  validates :group_permission_id, presence: true
  validates :group_type, presence: true

  # ============================
  # 4. 기본 스코프 (Soft Delete)
  # ============================
  scope :active, -> { where(deleted_at: nil) }
end
