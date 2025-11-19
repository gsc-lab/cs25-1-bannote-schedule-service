# class UserGroup < ApplicationRecord
#   belongs_to :user ,optional: true  #option나중에 삭제
#   belongs_to :group

#   validates :group_id, presence: true
#   # validates :created_at, presence: true 임시로끄기
# end


class UserGroup < ApplicationRecord
  self.record_timestamps = true
  belongs_to :user, optional: true
  belongs_to :group, optional: true
  validates :group_id, presence: true
  validates :group_id, presence: true
end
