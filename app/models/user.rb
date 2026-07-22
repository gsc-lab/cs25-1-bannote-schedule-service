class User < ApplicationRecord
  has_many :user_groups, primary_key: :user_number, foreign_key: :user_id
  has_many :groups, through: :user_groups

  belongs_to :department,
           primary_key: :department_code,
           foreign_key: :department_code,
           optional: true

  validates :name, presence: true, length: { maximum: 20 }
  validates :email, presence: true, length: { maximum: 50 }
  validates :department_code, presence: true, length: { maximum: 30 }

end
