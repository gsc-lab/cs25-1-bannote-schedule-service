class GroupTag < ApplicationRecord
    belongs_to :group
    belongs_to :tag

    validates :group_id, presence: true
    validates :tag_id, presence: true
end