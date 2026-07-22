class UserGroup < ApplicationRecord
  belongs_to :user, primary_key: :user_number, foreign_key: :user_id
  belongs_to :group
end
