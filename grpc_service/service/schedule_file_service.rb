# grpc_service/service/schedule_file_service.rb

require 'grpc'
require 'schedule_file/schedule_file_pb'
require 'schedule_file/schedule_file_service_services_pb'
require 'google/protobuf/well_known_types'


module Bannote::Scheduleservice::ScheduleFile::V1
  class ScheduleFileServiceHandler < Bannote::Scheduleservice::ScheduleFile::V1::ScheduleFileService::Service

    # 1. 일정 파일 조회 (파일 id 기준)
    def get_schedule_file(request, _call)
      file = ScheduleFile.find(request.file_id)

      Schedule::ScheduleFileResponse.new(
        file_id: file.id,
        schedule_link_id: file.schedule_link_id,
        file_path: file.file_path,
        created_by: file.created_by,
        created_at: Google::Protobuf::Timestamp.new(seconds: file.created_at.to_i)
      )
    rescue ActiveRecord::RecordNotFound
      GRPC::BadStatus.new_status_exception(
        GRPC::Core::StatusCodes::NOT_FOUND,
        "Schedule file not found"
      )
    end

    # 2. 일정 파일 삭제
    def delete_schedule_file(request, _call)
      file = ScheduleFile.find_by(id: request.file_id)

      if file
        file.destroy
        Schedule::DeleteScheduleFileResponse.new(success: true)
      else
        Schedule::DeleteScheduleFileResponse.new(success: false)
      end
    rescue StandardError => e
      puts "Error deleting file: #{e.message}"
      Schedule::DeleteScheduleFileResponse.new(success: false)
    end
  end
end
