class Tag < ApplicationRecord      
  has_many :group_tags
  has_many :groups, through: :group_tags

  validates :name, presence: true, length: { maximum: 50 }
  validates :created_by, presence: true
end