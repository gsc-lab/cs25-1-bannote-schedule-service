# app/helpers/role_helper.rb
require 'grpc'
require 'role/role_pb'
require 'role/service_services_pb'

module RoleHelper
  # 역할별 권한 레벨 테이블
    ROLE_LEVELS = {

    "student"   => 1,
    "keeper"    => 2,
    "leader"    => 3,
    "assistant" => 4,
    "professor" => 5,
    "admin"     => 6
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

    # raise GRPC::BadStatus.new_status_exception(
    #   GRPC::Core::StatusCodes::NOT_FOUND,
    #   "해당 사용자를 찾을 수 없습니다."
    # ) if user.nil?
  # DB에 없어도 임시로 user_id = 0 으로 통과시킴
    user_id = user ? user.id : 0
    [user.id, user_role]
  end

  # # 권한 확인 (임시)
  # def self.has_authority?(user_id, required_level)
  #   puts "임시로 권한 확인 통과 (Kafka 미구현 상태)"
  #   true
  # end
end
