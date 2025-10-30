class GroupTag < ApplicationRecord
    belongs_to :group, optional: true #나중에optional 제거
    belongs_to :tag, optional: true#나중에optional 제거
    belongs_to :user, optional: true
    validates :group_id, presence: true
    validates :tag_id, presence: true
end