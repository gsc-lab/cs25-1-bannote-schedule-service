require 'grpc'
require 'schedule/schedule_pb'
require 'schedule/schedule_service_services_pb'
require 'google/protobuf/well_known_types'
require 'securerandom'
require_relative '../helpers/Role_helper'

# Rails 모델을 명시적으로 alias로 등록
AppSchedule      = ::Schedule
AppScheduleLink  = ::ScheduleLink

module Bannote::Scheduleservice::Schedule::V1
  class ScheduleServiceHandler < ScheduleService::Service

    # 1. 일정 생성 (Schedule + ScheduleLink 자동 생성)
    # def create_schedule(request, call)
    #   user_id, role = [1, "admin"] # TokenHelper.verify_token(call)
    #   raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::UNAUTHENTICATED, "인증 실패") if user_id.nil?

    #   group = ::Group.find_by(id: request.group_id)
    #   raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "그룹을 찾을 수 없습니다.") if group.nil?

    #   # 권한 검증
    #   if group.group_type_id == 1 ||group.group_type_id == 2
    #     # 정규 수업 그룹 → 조교 이상만 가능
    #     unless RoleHelper.has_authority?(user_id, 4)
    #       raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::PERMISSION_DENIED, "이 그룹은 조교 이상만 일정을 생성할 수 있습니다.")
    #     end
    #   else
    #     # 개인/기타 그룹 → 그룹에 속한 멤버면 가능
    #     is_member = ::UserGroup.exists?(user_id: user_id, group_id: group.id)
    #     unless is_member
    #       raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::PERMISSION_DENIED, "이 그룹에 속하지 않아 일정을 생성할 수 없습니다.")
    #     end
    #   end

    #   # 유효성 검증
    #   # raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, "제목은 필수입니다.") if request.title.nil? || request.title.strip.empty?
    #   raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, "시간 입력은 필수입니다.") if request.start_date.nil? || request.end_date.nil?

    #   start_time = Time.at(request.start_date.seconds)
    #   end_time = Time.at(request.end_date.seconds)
    #   raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, "종료시간은 시작시간 이후여야 합니다.") if end_time <= start_time

    #   ActiveRecord::Base.transaction do
    #     #  일정 링크 생성
    #     link_data = request.link

    #     # 1-1. 일정 링크 생성
    #     link = ScheduleLink.create!(
    #       title: request.title,
    #       description: request.description,
    #       place_text: request.place_text,
    #       start_time: start_time,
    #       end_time: end_time,
    #       is_allday: request.is_allday || false,
    #       created_by: user_id
    #     )

    #     # 1-2. 일정 생성
    #     schedule = Schedule.create!(
    #       group_id: group.id,
    #       schedule_link_id: link.id,
    #       schedule_code: SecureRandom.hex(8),
    #       color: request.is_highlighted ? "highlight" : "normal",
    #       start_date: request.start_date,
    #       end_date: request.end_date,
    #       comment: request.comment,
    #       created_by: user_id
    #     )

    #     # 응답
    #     Schedule::ScheduleResponse.new(
    #       schedule_id: schedule.id,
    #       schedule_code: schedule.schedule_code,
    #       group_id: schedule.group_id,
    #       code: group.group_code,
    #       schedule_link_id: schedule.schedule_link_id,
    #       color: schedule.color,
    #       created_by: schedule.created_by,
    #       created_at: Google::Protobuf::Timestamp.new(seconds: schedule.created_at.to_i)
    #     )
    #   end
    # rescue => e
    #   raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
    # end
    def create_schedule(request, call)
      user_id, role = [1, "admin"]
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::UNAUTHENTICATED, "인증 실패") if user_id.nil?

      group = ::Group.find_by(id: request.group_id)
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "그룹을 찾을 수 없습니다.") if group.nil?

      # 권한 검증
      if group.group_type_id.in?([1, 2])
        unless RoleHelper.has_authority?(user_id, 4)
          raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::PERMISSION_DENIED, "이 그룹은 조교 이상만 일정을 생성할 수 있습니다.")
        end
      else
        is_member = ::UserGroup.exists?(user_id: user_id, group_id: group.id)
        raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::PERMISSION_DENIED, "이 그룹에 속하지 않아 일정을 생성할 수 없습니다.") unless is_member
      end

      # 유효성 검증
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, "시간 입력은 필수입니다.") if request.start_date.nil? || request.end_date.nil?

      start_time = Time.at(request.start_date.seconds)
      end_time = Time.at(request.end_date.seconds)
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, "종료시간은 시작시간 이후여야 합니다.") if end_time <= start_time

      link_data = request.link
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, "링크 데이터가 필요합니다.") if link_data.nil?

      ActiveRecord::Base.transaction do
        # 1-1. 일정 링크 생성
        link = ::ScheduleLink.create!(
          title: link_data.title,
          description: link_data.description,
          place_id: link_data.place_id.presence,
          place_text: link_data.place_text.presence,
          start_time: Time.at(link_data.start_time.seconds),
          end_time: Time.at(link_data.end_time.seconds),
          is_allday: link_data.is_allday || false,
          created_by: user_id
        )

        # 1-2. 일정 생성
        schedule = ::Schedule.create!(
          group_id: group.id,
          schedule_link_id: link.id,
          schedule_code: SecureRandom.hex(8),
          color: request.is_highlighted ? "highlight" : "normal",
          start_date: Time.at(request.start_date.seconds),
          end_date: Time.at(request.end_date.seconds),
          memo: request.comment,
          created_by: user_id
        )

        # 응답
        CreateScheduleResponse.new(
          schedule: Schedule.new(
            schedule_id: schedule.id,
            code: schedule.schedule_code,
            group_id: schedule.group_id,
            schedule_link_id: schedule.schedule_link_id,
            color: schedule.color,
            comment: schedule.memo,
            created_by: schedule.created_by,
            created_at: Google::Protobuf::Timestamp.new(seconds: schedule.created_at.to_i)
          )
        )
      end
    rescue => e
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
    end

    # 2. 일정 목록 조회 (그룹 ID별)
    def get_schedule_list(request, call)
      user_id, role = [1, "admin"]

      user = ::User.find_by(id: user_id)
      allowed_group_ids = user.groups.pluck(:id)
      target_group_ids = request.group_ids & allowed_group_ids

      schedules = Schedule.where(group_id: target_group_ids)
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
    def get_schedule(request, call)
      user_id, role = [1, "admin"]
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::UNAUTHENTICATED, "인증 실패") if user_id.nil?

      schedule = ::Schedule.includes(:group, :schedule_link).find_by(id: request.schedule_id)
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "일정을 찾을 수 없습니다.") if schedule.nil?

      group = schedule.group
      is_member = ::UserGroup.exists?(user_id: user_id, group_id: group.id)
      unless is_member
        raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::PERMISSION_DENIED, "이 그룹에 속하지 않아 일정을 조회할 수 없습니다.")
      end

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

    # 4. 일정 수정 (Schedule + ScheduleLink 동시 수정)
    def update_schedule(request, call)
      user_id, role = [1, "admin"]

      schedule = ::Schedule.find_by(id: request.schedule_id)
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "일정을 찾을 수 없습니다.") if schedule.nil?

      group = schedule.group
      if group.group_type_id == 1 || group.group_type_id == 2
        unless RoleHelper.has_authority?(user_id, 4)
          raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::PERMISSION_DENIED, "정규 수업 그룹의 일정은 조교 이상만 수정 가능합니다.")
        end
      else
        is_member = ::UserGroup.exists?(user_id: user_id, group_id: group.id)
        unless is_member
          raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::PERMISSION_DENIED, "이 그룹에 속하지 않아 일정을 수정할 수 없습니다.")
        end
      end

      link_data = schedule.schedule_link
      schedule.update!(
        comment: request.comment.presence || schedule.comment,
        color: request.is_highlighted ? "highlight" : "normal"
      )

      link.update!(
        title: request.title.presence || link.title
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
    end

    # 5. 일정 삭제 (ScheduleLink도 함께 삭제)
    def delete_schedule(request, call)
      user_id, role = [1, "admin"]
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::UNAUTHENTICATED, "인증 실패") if user_id.nil?

      schedule = ::Schedule.includes(:group, :schedule_link).find_by(id: request.schedule_id)
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "일정을 찾을 수 없습니다.") if schedule.nil?

      group = schedule.group

      # 권한 검증
      case group.group_type_id 
      when 1,2
        unless RoleHelper.has_authority?(user_id,4)
          raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::PERMISSION_DENIED, "정규 수업 그룹의 일정은 조교 이상만 삭제할 수 있습니다.")
        end
      else #개인그룹
        is_member = ::UserGroup.exists?(user_id: user_id, group_id: group.id)
        unless is_member
          raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::PERMISSION_DENIED, "이 그룹에 속하지 않아 일정을 삭제할 수 없습니다.")
        end
      end

      ActiveRecord::Base.transaction do
        schedule.schedule_link&.destroy!
        schedule.destroy!
      end

      Schedule::DeleteScheduleResponse.new(success: true)
    rescue => e
      puts "일정 삭제 실패: #{e.message}"
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INTERNAL, "삭제 중 오류 발생: #{e.message}")
    end
  end
end
