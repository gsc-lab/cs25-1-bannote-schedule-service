class GroupPermission < ApplicationRecord
  has_many :groups, foreign_key: :group_permission_id, dependent: :restrict_with_exception

  validates :permission, presence: true, inclusion: { in: ['우선1', '우선2', '우선3'] }

end
