# grpc_service/service/schedule_file_service.rb

require 'grpc'
require 'schedule_file/schedule_file_pb'
require 'schedule_file/schedule_file_service_services_pb'
require 'google/protobuf/well_known_types'

module Bannote
  module Scheduleservice
    module ScheduleFile
      module V1
        class ScheduleFileServiceHandler < Bannote::Scheduleservice::ScheduleFile::V1::ScheduleFileService::Service

          # 1. 일정 파일 조회 (파일 id 기준)
          def get_schedule_file(request, _call)
            file = ::ScheduleFile.find(request.file_id)

            Bannote::Scheduleservice::ScheduleFile::V1::GetScheduleFileResponse.new(
              schedule_file: Bannote::Scheduleservice::ScheduleFile::V1::ScheduleFile.new(
                file_id: file.id,
                schedule_link_id: file.schedule_link_id,
                file_path: file.file_path,
                created_by: file.created_by,
                created_at: Google::Protobuf::Timestamp.new(seconds: file.created_at.to_i),
                updated_at: file.updated_at ? Google::Protobuf::Timestamp.new(seconds: file.updated_at.to_i) : nil
              )
            )
          rescue ActiveRecord::RecordNotFound
            raise GRPC::NotFound.new("Schedule file not found")
          rescue => e
            raise GRPC::Internal.new("Internal error: #{e.message}")
          end

          # 2. 일정 파일 삭제
          def delete_schedule_file(request, _call)
            file = ::ScheduleFile.find_by(id: request.file_id)

            if file
              file.destroy
              Bannote::Scheduleservice::ScheduleFile::V1::DeleteScheduleFileResponse.new(success: true)
            else
              raise GRPC::BadStatus.new_status_exception(
                GRPC::Core::StatusCodes::NOT_FOUND,
                "Schedule file not found"
              )
            end
          rescue => e
            puts "Error deleting file: #{e.message}"
            raise GRPC::Internal.new("Internal error: #{e.message}")
          end

        end
      end
    end
  end
end
