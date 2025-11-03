# 1. gRPC 라이브러리 로드
require 'grpc'

# 2. Rails 환경 로드
require File.expand_path('../config/environment', __dir__)
Rails.application.eager_load!

# 3. Ruby 검색 경로 추가
lib_dir = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)
# 서비스 구현 파일이 있는 service 디렉토리도 경로에 추가
service_dir = File.expand_path('service', __dir__)
$LOAD_PATH.unshift(service_dir) unless $LOAD_PATH.include?(service_dir)


# 4. gRPC 파일 로드
require 'common_pb'

# buf가 생성한 pb 파일들 로드
require 'group/group_pb'
require 'group/group_service_services_pb'
require 'group_tag/group_tag_pb'
require 'group_tag/group_tag_service_services_pb'
require 'tag/tag_pb'
require 'tag/tag_service_services_pb'
require 'schedule/schedule_pb'
require 'schedule/schedule_service_services_pb'
require 'schedule_link/schedule_link_pb'
require 'schedule_link/schedule_link_service_services_pb'
require 'schedule_file/schedule_file_pb'
require 'schedule_file/schedule_file_service_services_pb'

# 직접 구현한 서비스 핸들러 파일들 로드
require_relative 'service/group_service'
require_relative 'service/group_tag_service'
# require_relative 'service/user_group_service'
require_relative 'service/tag_service'
require_relative 'service/schedule_service'
require_relative 'service/schedule_link_service'
require_relative 'service/schedule_file_service'
require_relative './health_check_service'

module Bannote
  module Scheduleservice
  end
end

# 5. gRPC 서버 실행
def main
  port = ENV.fetch('GRPC_PORT', '55005')
  server = GRPC::RpcServer.new
  server.add_http2_port("0.0.0.0:#{port}", :this_port_is_insecure)

  #  서비스 등록 (run_till_terminated 이전에 해야 함)
  server.handle(Bannote::Scheduleservice::Group::V1::GroupServiceHandler.new)
  server.handle(Bannote::Scheduleservice::GroupTag::V1::GroupTagServiceHandler.new)
  server.handle(Bannote::Scheduleservice::Tag::V1::TagServiceHandler.new)
  # server.handle(Bannote::Scheduleservice::User::V1::UserGroupServiceHandler.new)
  server.handle(Bannote::Scheduleservice::Schedule::V1::ScheduleServiceHandler.new)
  server.handle(Bannote::Scheduleservice::ScheduleLink::V1::ScheduleLinkServiceHandler.new)
  server.handle(Bannote::Scheduleservice::ScheduleFile::V1::ScheduleFileServiceHandler.new)
  server.handle(Grpc::Health::V1::HealthServiceHandler)

  puts "gRPC 서버가 #{port} 포트에서 실행 중입니다..."

  #  서버 실행 (등록된 서비스 포함)
  server.run_till_terminated_or_interrupted(['INT', 'TERM'])
  puts "서버가 종료되었습니다."
end

main
