class GroupPermission < ApplicationRecord
    has_many :groups

    validates :permission, presence: true, inclusion: { in:['우선1','우선2','우선3']}

     # 권한 값은 스터디룸 예약 서비스 우선순위를 나타냄
end