# grpc_service/service/schedule_file_service.rb

require 'grpc'
require 'schedule_file/schedule_file_pb'
require 'schedule_file/schedule_file_service_services_pb'
require 'google/protobuf/well_known_types'
require_relative '../helpers/Role_helper'
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
            file_id = request.file_id
            raise GRPC::InvalidArgument.new("file_id는 필수 입니다")if file_id.nil? || file_id <= 0
            
            # 파일 조회
            file = ::ScheduleFile.find(request.file_id)
            raise GRPC::InvalidArgument.new("scheuleLink가 존재 하지않습니디ㅏ")if file.schedule_link_id.nil?
            # 연결된 일정 링크 조회
            schedule_link =::ScheduleLink.find_by(id:file.schedule_link_id)
            raise GRPC::NotFound.new("연결된 일정 링크를 찾을 수 없습니다")if schedule_link.nil?

            #인증 처리
            begin
              user_id,role = TokenHelper.verify_token(call)
            rescue
              raise GRPC::Unauthenticated.new("로그인이 필요합니다")
            end

           # 그룹 소속 여부확인
           group = schedule_link.group
           raise GRPC::NotFound.new("해당 일정이 속한 그룹을 찾을 수 없습니다")if group.nil?
            #그룹에 속하는지 않하는지 여부
           is_member = ::UserGroup.exists?(user_id: user_id, group_id: group.id) # 위에 group에서 가져왔기떄문에 그대로 . 해서 사용가능

           unless is_member
            raise  GRPC::PermissionDenied.new("이 그룹에 속하지 않아 파일을 조회할 수 없습니다.")
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
            #파일 조회
            file = ::ScheduleFile.find_by(id: request.file_id)
            raise GRPC::NotFound.new("Schedule file not found")if file.nil?

            #인증 맟 권한 검증
            begin
              user_id,role = TokenHelper.verify_token(call)
            rescue
              raise GRPC::Unauthenticated.new("로그인이 필요합ㄴ디ㅏ")
            end

            #연결된 일정 및 그룹 조회
            schedule_link = ::ScheduleLink.find_by(id: file.schedule_link_id)
            raise GRPC::NotFound.new("연결된 일정 링크를 찾을 수 없습니다.") if schedule_link.nil?

            group = schedule_link.group
            raise GRPC::NotFound.new("해당 일정이 속한 그룹을 찾을 수 없습니다.") if group.nil?

            
            #권한 검증
            case group.group_type_id
            when 1,2
              unless RoleHelper.has_authority?(user_id,4)
                raise GRPC::PermissionDenied.new("정규 수업 그룹의 파일은 조교 이상만 삭제 할 수 있습니다")
              end
            
            else

              #개인 그룹은 해당 그룹에 속해있는 맴버면 삭제가능
              is_member = ::UserGroup.exists?(user_id: user_id,group_id: group.id)
              unless is_member
                raise GRPC::PermissionDenied.new("이 그룹에 속하지 않아 파일을 삭제 할 수 없습니다")
              end

              #스케줄 링크 가지고있는지 확인
              unless schedule_link.present? && schedule_link.group_id == group.id
                raise GRPC::PermissionDenied.new("이 파일은 해당 그룹의 스케줄과 연결되어 있지 않습니다")
              end
            end

            #MinIo객체 삭제


            #db레코드 삭제

            file.destroy!
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
