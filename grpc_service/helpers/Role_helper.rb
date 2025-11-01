require 'grpc'
require 'role/role_pb'
require 'role/service_services_pb'

module RoleHelper
  USER_SERVICE_ADDRESS = "user_service:55052"

  def self.check_authority(user_id, required_level)
    puts "임시로 권한 확인 통과 (Kafka 대기 중)"
    true
  end
end
