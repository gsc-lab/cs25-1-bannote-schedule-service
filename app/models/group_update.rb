class  GroupUpdate < ApplicationRecord

    belongs_to :group

    validates :group_id, presence: true
    validates :created_at, presence: true
end