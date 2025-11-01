# app/helpers/role_helper.rb
require 'grpc'
require 'role/role_pb'
require 'role/service_services_pb'

module RoleHelper
  def self.has_authority?(user_id, required_level)
    puts "임시로 권한 확인 통과 (Kafka 미구현 상태)"
    true
  end
end
