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
    user_code = call.metadata["x-user-code"]
    user_role = call.metadata["x-user-role"]

    raise GRPC::BadStatus.new_status_exception(
      GRPC::Core::StatusCodes::UNAUTHENTICATED,
      "x-user-code가 누락되었습니다."
    ) if user_code.blank?

    user = ::User.find_by(user_number: user_code)

    raise GRPC::BadStatus.new_status_exception(
      GRPC::Core::StatusCodes::NOT_FOUND,
      "해당 사용자를 찾을 수 없습니다."
    ) if user.nil?

    # DB에 없어도 임시로 user_id = 0 으로 통과시킴
    user_id = user ? user.id : 0
    [ user_id, user_role ]
  end

  # 권한 확인 (레벨 비교 방식으로 수정)
  def self.has_authority?(user_role, required_level)
    # 역할 문자열이 ROLE_LEVELS에 존재하지 않으면 0으로 처리
    user_level = ROLE_LEVELS[user_role.to_s] || 0

    puts "[RoleHelper] 권한 확인: #{user_role} (#{user_level}) / 필요 레벨: #{required_level}"

    # user_level이 required_level 이상이면 true
    user_level >= required_level
  end
end
