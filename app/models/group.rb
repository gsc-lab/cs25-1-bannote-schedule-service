class Group < ApplicationRecord
  belongs_to :group_permission, foreign_key: :group_type_id

  has_many :group_tags, dependent: :destroy
  has_many :tags, through: :group_tags
  has_many :group_updates, dependent: :destroy
  has_many :user_groups, dependent: :destroy
  has_many :users, through: :user_groups

  validates :group_name, presence: true, length: { maximum: 100 }
  validates :color_default, presence: true
  validates :is_public, inclusion: { in: [true, false] }
  validates :group_type_id, presence: true

  scope :active, -> { where(deleted_at: nil) }
end
