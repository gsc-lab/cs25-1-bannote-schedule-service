require 'grpc'
require 'schedule/schedule_pb'
require 'schedule/schedule_service_services_pb'
require 'google/protobuf/well_known_types'
require 'securerandom'

module Bannote::Scheduleservice::Schedule::V1
  class ScheduleServiceHandler < ScheduleService::Service

    # 1. 일정 생성 (Schedule + ScheduleLink 자동 생성)
    def create_schedule(request, _call)
      ActiveRecord::Base.transaction do
        # 1-1. 일정 링크 생성
        link = ScheduleLink.create!(
          title: request.comment.presence || "새 일정",
          start_time: Time.at(request.start_date.seconds),
          end_time: Time.at(request.end_date.seconds),
          is_allday: false,
          created_by: 1 # Placeholder for created_by
        )

        # 1-2. 일정 생성
        group = ::Group.find(request.group_id) # db에서 그룹 조회
        schedule = Schedule.create!(
          group_id: request.group_id,
          group_code: group.group_code,
          schedule_link_id: link.id,
          schedule_code: SecureRandom.hex(8), #자동 생성
          color: request.is_highlighted ? "highlight" : "normal",
          created_by: 1, # Placeholder for created_by
          comment: request.comment
        )

        # 응답 변환
        Schedule::ScheduleResponse.new(
          schedule_id: schedule.id,
          schedule_code: schedule.schedule_code,
          group_id: schedule.group_id,
          code: schedule.group.group_code,
          schedule_link_id: schedule.schedule_link_id,
          color: schedule.color,
          created_by: schedule.created_by,
          created_at: Google::Protobuf::Timestamp.new(seconds: schedule.created_at.to_i)
        )
      end
    rescue => e
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
    end

    # 2. 일정 목록 조회 (그룹 ID별)
    def get_schedule_list(request, _call)
      schedules = Schedule.where(group_id: request.group_ids)
                          .includes(:schedule_link)
                          .order(created_at: :desc)

      schedule_responses = schedules.map do |s|
        Schedule::ScheduleResponse.new(
          schedule_id: s.id,
          schedule_code: s.schedule_code,
          group_id: s.group_id,
          code: s.group.group_code,
          schedule_link_id: s.schedule_link_id,
          color: s.color,
          created_by: s.created_by,
          created_at: Google::Protobuf::Timestamp.new(seconds: s.created_at.to_i)
        )
      end

      Schedule::ScheduleListResponse.new(schedules: schedule_responses)
    end

    # 3. 일정 상세 조회
    def get_schedule(request, _call)
      s = Schedule.find(request.schedule_id)
      Schedule::ScheduleResponse.new(
        schedule_id: s.id,
        schedule_code: s.schedule_code,
        group_id: s.group_id,
        code: s.group.group_code,
        schedule_link_id: s.schedule_link_id,
        color: s.color,
        created_by: s.created_by,
        created_at: Google::Protobuf::Timestamp.new(seconds: s.created_at.to_i)
      )
    rescue ActiveRecord::RecordNotFound
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "Schedule not found")
    end

    # 4. 일정 수정 (Schedule + ScheduleLink 동시 수정)
    def update_schedule(request, _call)
      schedule = Schedule.find(request.schedule_id)
      link = schedule.schedule_link

      schedule.update!(
        comment: request.comment.presence || schedule.comment,
        color: request.is_highlighted ? "highlight" : "normal"
      )

      link.update!(
        title: request.comment.presence || link.title
      )

      Schedule::ScheduleResponse.new(
        schedule_id: schedule.id,
        schedule_code: schedule.schedule_code,
        group_id: schedule.group_id,
        code: schedule.group.group_code,
        schedule_link_id: link.id,
        color: schedule.color,
        created_by: schedule.created_by,
        created_at: Google::Protobuf::Timestamp.new(seconds: schedule.created_at.to_i)
      )
    rescue ActiveRecord::RecordNotFound
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "Schedule not found")
    end

    # 5. 일정 삭제 (ScheduleLink도 함께 삭제)
    def delete_schedule(request, _call)
      schedule = Schedule.find_by(id: request.schedule_id)

      if schedule
        ActiveRecord::Base.transaction do
          schedule.schedule_link.destroy if schedule.schedule_link
          schedule.destroy
        end
        Schedule::DeleteScheduleResponse.new(success: true)
      else
        Schedule::DeleteScheduleResponse.new(success: false)
      end
    rescue => e
      puts "Error deleting schedule: #{e.message}"
      Schedule::DeleteScheduleResponse.new(success: false)
    end
  end
end