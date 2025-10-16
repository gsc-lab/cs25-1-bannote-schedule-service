class UserGroup < ApplicationRecord
  belongs_to :user
  belongs_to :group

  validates :group_id, presence: true
  validates :created_at, presence: true
end