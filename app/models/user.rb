class User < ApplicationRecord
  # 관계 설정
  has_many :user_groups, dependent: :destroy
  has_many :groups, through: :user_groups

  # 유효성 검사
  validates :name, presence: true, length: { maximum: 20 }
  validates :email, presence: true, length: { maximum: 50 }
  validates :department, presence: true, length: { maximum: 30 }


end