require 'grpc'
require 'role/role_pb'
require 'role/service_services_pb'

module RoleHelper
  # 역할별 권한 레벨 테이블
  ROLE_LEVELS = {
    "STUDENT" => 1,
    "DOORKEEPER"  => 2,
    "CLASS_REP"  => 3,
    "TA" => 4,
    "PROFESSOR" => 5,
    "ADMIN"  => 6
  }.freeze

  # 인증 + 유저 조회
  def self.verify_user(call)
    puts "==============================================="
    puts "[DEBUG] RAW METADATA = #{call.metadata.inspect}"
    puts "==============================================="

    user_code = call.metadata["x-user-code"]
    user_role = call.metadata["x-user-role"]&.upcase

    puts "[DEBUG] user_code(raw) = #{user_code.inspect}"
    puts "[DEBUG] user_role(raw) = #{user_role.inspect}"

    raise GRPC::BadStatus.new_status_exception(
      GRPC::Core::StatusCodes::UNAUTHENTICATED,
      "x-user-code가 누락되었습니다."
    ) if user_code.blank?

    user = ::User.find_by(user_number: user_code)

    raise GRPC::BadStatus.new_status_exception(
      GRPC::Core::StatusCodes::NOT_FOUND,
      "해당 사용자를 찾을 수 없습니다."
    ) if user.nil?

    [ user.user_number, user_role ]
  end

end
