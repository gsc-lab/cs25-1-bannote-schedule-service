require 'grpc'
require 'schedule/schedule_pb'
require 'schedule/schedule_service_services_pb'
require 'google/protobuf/well_known_types'
require 'securerandom'
require_relative '../helpers/token_helper'
require_relative '../helpers/Role_helper'

module Bannote::Scheduleservice::Schedule::V1
  class ScheduleServiceHandler < ScheduleService::Service

    # 1. 일정 생성 (Schedule + ScheduleLink 자동 생성)
    def create_schedule(request,call)
      # 인증
      user_id,role = TokenHelper.verify_token(call)
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes:::UNAUTHENTICATED, "인증 실패") if user_id.nil?  
      
      user = ::User.find_by(id: user_id)
      group = ::Group.find(request.group_id) 

      if group.group_type_id == 1
        unless RoleHelper.has_authority?(user_id,4)
          raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::PERMISSION_DENIED, "이 그룹은 조교 이상만 일정을 생성할 수 있습니다.")
        end
      end
      
      #유효성
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT,"제목은 필수 입니다")
      raise GRPC::BadStauts.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, "시간 입력은 필수입니다.") if request.start_time.nil? || request.end_time.nil?

      start_time = Time.at(request.start_time.seconds)
      end_time = Time.at(request.end_time.seconds)
      raise GRPC::BadStauts.new_status_exception(GRPC::StatusCodes::INVALID_ARGUMENT,"종료시간은 시작시간 이후여야합닏다 ")if end_time <= start_time

 
      ActiveRecord::Base.transaction do
        # 1-1. 일정 링크 생성
        link = ScheduleLink.create!(
          title: request.title,
          start_time: start_time,
          end_time: end_time,
          is_allday: request.is_allday || false,
          created_by: user_id
        )

        # 1-2. 일정 생성
     
        schedule = Schedule.create!(
          group_id: group.id, 
          group_code: group.group_code,
          schedule_link_id: link.id,
          schedule_code: SecureRandom.hex(8), #자동 생성
          color: request.is_highlighted ? "highlight" : "normal",
          created_by: user_id,
          comment: request.comment
        )

        # 응답 변환
        Schedule::ScheduleResponse.new(
          schedule_id: schedule.id,
          schedule_code: schedule.schedule_code,
          group_id: schedule.group_id,
          code: group.group_code,
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
    def get_schedule_list(request, call)
      #인증
      user_id,role = TokenHelper.verify_token(call)
      user = :: User.find(id: user_id)

      #사용자가 속한 그룹만 조회 가능
      allowed_group_ids = user.group.pluck(:id)
      target_group_ids = request.group_ids & allowed_group_ids

      
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
    def get_schedule(request, call)
      #인증
      user_id,role = TokenHelper.verify_token(call)
      raise GRPC::BadStatus.new_status_exception(
        GRPC::Core::StatusCodes::UNAUTHENTICATED, "인증 실패") if user_id.nil?

      #일정 조회
      schedule = ::Schedule.includes(:group,:schedule_link).find_by(id: request.schedule_id)
      raise GRPC::BadStatus.new_status_exception(
        GRPC::Core::StatusCodes::NOT_FOUND,"일정을 찾을 수 없습니다")if schedule.nil?
      
      
      unless %w[admin professor assistant].include?(role)
        user = ::User.find_id(id: user_id)
        user_groups = user.groups.pluck(:id)

        unless user_groups.include?(schedule.group_id)
          raise GRPC::BadStatus.new_status_exception( GRPC::Core::StatusCodes::PERMISSION_DENIED,"해당 그룹에 속하지 않아 일정을 조회할 수 없습니다.")
        end
      end
      
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
    def update_schedule(request,call)
      #인증
      user_id,role = TokenHelper.verify_token(call)

      
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
    def delete_schedule(request, call)
      #인증 
      user_id,role = TokenHelper.verify_token(call)
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::UNAUTHENTICATED,"인증 실패")if user_id.nil?
      
      #일정 조회
      schedule = ::Schedule.includes(:group,:schedule_link).find_by(id: request.schedule_id)
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCode::NOT_FOUND,"일정을 찾을 수 없습니다")if schedule.nil?

      #권한
      unless %w[admin professor assistant].includ?(role)
        user = ::User.find_by(id: user_id)
        user_groups = user.groups.pluck(:id)
        unless user_groups.include?(schedule.group_id)
          raise GPRC::BadStatus.new_Status_exception(GRPC::Core::StatusCodes::PERMISSION_DENIED,"해당 그룹에 속하지 않아 일정을 삭제할 수 없습니다.") 
        end
      end
      
      ActiveRecord::Base.transaction do
      schedule.schedule_link&.destroy!
      schedule.destroy!
      end
     
      Schedule::DeleteScheduleResponse.new(success: true)
    rescue ActiveRecord::RecordNotFound
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "일정을 찾을 수 없습니다.")
    rescue GRPC::BadStaus => e
      raise e
    rescue => e
      puts "schedule 삭제 실패 #{e.message}"
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INTERNAL, "삭제 중 오류 발생: #{e.message}")
    end
  end
end