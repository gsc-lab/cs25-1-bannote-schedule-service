class  GroupUpdate < ApplicationRecord

    belongs_to :group, optional: true # optional삭제해줘야함

    validates :group_id, presence: true
    # validates :created_at, presence: true 나중에는 주석 해제
end