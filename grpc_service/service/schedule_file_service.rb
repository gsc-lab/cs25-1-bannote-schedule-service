# grpc_service/service/schedule_file_service.rb

require 'grpc'
require 'schedule_file/schedule_file_pb'
require 'schedule_file/schedule_file_service_services_pb'
require 'google/protobuf/well_known_types'
require_relative '../helpers/token_helper'
require 'aws-sdk-s3'

module Bannote
  module Scheduleservice
    module ScheduleFile
      module V1
        class ScheduleFileServiceHandler < Bannote::Scheduleservice::ScheduleFile::V1::ScheduleFileService::Service

          #Minio파일 

          # 1. 일정 파일 조회 (파일 id 기준)
          def get_schedule_file(request, call)
            #1. 파싱
            find_id = request.find_id
            raise GRPC::InvalidAtgument.new("file_id는 필수 입니다")if file_id.nil? || file_id <= 0
          
            file = ::ScheduleFile.find(request.file_id)
            raise GRPC::InvalidArgument.new("scheuleLink가 존재 하지않습니디ㅏ")if file.schedule_link_id.nil?

            schedule_link =::ScheduleLink.find_by(id:file.schedule_link_id)
            raise GRPC::NotFound.new("연결된 일정 링크를 찾을 수 없습니다")if schedule_link.nil?

            #인증 처리
            begin
              user_id,role = TokenHelper.verify_token(call)
            rescue
              raise GRPC::Unauthenticated.new("로그인이 필요합니다")
            end

            # 접근 허용 로직
            authorized = %w[admin professor assistant].include?(role) ||  # 조교님 이상
                          file.created_by == user_id ||                    # 생성자
                          schedule_link.user_id == user_id                 # 스케줄 링크를 들고 있는지 확인
                                                                         
              #없으면 error반환
            unless authorized
              raise GRPC::PermissionDenied.new("파일 접근 권한이 없습니다")  
            end
            #presigned url생성

            
            #정상 응답 반환
            Bannote::Scheduleservice::ScheduleFile::V1::GetScheduleFileResponse.new(
              schedule_file: Bannote::Scheduleservice::ScheduleFile::V1::ScheduleFile.new(
                file_id: file.id,
                schedule_link_id: file.schedule_link_id,
                file_path: file.file_path,
                #  presigned_url: presigned_url
                created_by: file.created_by,
                created_at: Google::Protobuf::Timestamp.new(seconds: file.created_at.to_i),
                updated_at: file.updated_at ? Google::Protobuf::Timestamp.new(seconds: file.updated_at.to_i) : nil
              )
            )

          #예외처리
          rescue ActiveRecord::RecordNotFound
            raise GRPC::NotFound.new("스케줄 파일이없습니다")
          rescue => e
            raise GRPC::Internal.new("Internal error: #{e.message}")
          end

          # 2. 일정 파일 삭제
          def delete_schedule_file(request, call)
            #1.파싱
            file_id = request.file_id
            raise GRPC::InvalidArgument.new("file_id는 필수입니다")if file_id.nil? || file_id <= 0

            file = ::ScheduleFile.find_by(id: request.file_id)
            raise GRPC::NotFound.new("Schedule file not found")if file.nil?

            #인증 맟 권한 검증
            begin
              user_id,role = TokenHelper.verify_token(call)
            rescue
              raise GRPC::Unauthenticated.new("로그인이 필요합ㄴ디ㅏ")
            end

             authorized = %w[admin professor assistant].include?(role) || file.created_by == user_id
            unless authorized
              raise GRPC::PermissionDenied.new("파일 삭제 권한이 없습니다.")
            end

            #MinIo객체 삭제


            #db레코드 삭제

            file.destroy
            #응답
            Bannote::Scheduleservice::ScheduleFile::V1::DeleteScheduleFileResponse.new(success: true)

          rescue ActiveRecord::RecordNotFound
            raise GRPC::NotFound.new("Schedule file not found")
          rescue => e
            puts "Error deleting file: #{e.message}"
            raise GRPC::Internal.new("Internal error: #{e.message}")
          end
        
        end
      end
    end
  end
end
