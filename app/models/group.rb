class Group < ApplicationRecord
    #1. 관계
    belongs_to :group_permission #그룹은 권한 하나애에 속함
    has_many :group_tags #그룹은 여러 태그 연결을 가짐
    has_many :tags, through: :group_tags#그룹태그를 통해 여러 태그를 가짐 
    has_many :group_updates
    has_many :user_groups, dependent: :destroy
    has_many :users, through: :user_groups

    #2. 유효성 검사
    validates :group_name, presence: true, length: { maximum: 100 }
    validates :color_default , presence:true
    validates :is_public, inclusion: {in:[true,false]}

    #3.기본 스코프/논리 삭제
    scope :active, -> {where(delete_at:nil)}


end