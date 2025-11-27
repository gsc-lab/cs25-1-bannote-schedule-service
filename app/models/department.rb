class Department < ApplicationRecord
  has_many :users,
           primary_key: :department_code,
           foreign_key: :department_code
end
