require 'grpc'
require 'role/role_pb'
require 'role/role_service_services_pb'

module RoleHelper
    USER_SERVICE_ADDRESS = "user_service:55052"

    def self.check_authority(user_id,required_level)
        role_stub = Bannote::Userservice::Role::V1::RoleService::Stub.new(
            USER_SERVICE_ADDRESS,
            :this_channel_is_insecure
        )
        req = Bannote::Userservice::Role::V1::CheckUserHasAuthorityRequest.new(
            user_code: user_id,
            required_level: required_level
        )
        res =  role_stub.check_user_has_authority(req)
        res.has_authority
    rescue GPRC::BadStatus => e
        puts "RoleService 호출 실패: #{e.message}"
        false
    end
end
