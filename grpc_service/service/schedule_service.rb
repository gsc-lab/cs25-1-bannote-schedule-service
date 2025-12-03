require 'grpc'
require 'schedule/schedule_pb'
require 'schedule/schedule_service_services_pb'
require 'google/protobuf/well_known_types'
require 'securerandom'
require_relative '../helpers/Role_helper'
require_relative '../helpers/Datetime_helper'


# #최근에 저장된 모듈scheulde을 들고오기떄문에 삭제 해주고
# ::Object.send(:remove_const, :Schedule) if defined?(Schedule)
# Rails 모델을 명시적으로 alias로 등록
AppSchedule  = ::Schedule
AppScheduleLink  = ::ScheduleLink

module Bannote::Scheduleservice::Schedule::V1
  class ScheduleServiceHandler < ScheduleService::Service
    include DatetimeHelper 
    def create_schedule(request, call)
      current_user_number, role = RoleHelper.verify_user(call)
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::UNAUTHENTICATED, "인증 실패") if current_user_number.nil?

      group = ::Group.find_by(id: request.group_id)
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "그룹을 찾을 수 없습니다.") if group.nil?

      # 권한 검증
      if group.group_type_id.in?([1, 2])
        unless RoleHelper.has_authority?(role, "TA")
          raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::PERMISSION_DENIED, "이 그룹은 조교 이상만 일정을 생성할 수 있습니다.")
        end
      else
        is_member = ::UserGroup.exists?(user_id: current_user_number, group_id: group.id)
        raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::PERMISSION_DENIED, "이 그룹에 속하지 않아 일정을 생성할 수 없습니다.") unless is_member
      end

      # 링크 데이터 필수
      link_data = request.link
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, "링크 데이터가 필요합니다.") if link_data.nil?

      is_all_day = link_data.is_allday || false

      if !is_all_day
        # 일반 일정은 start_at, end_at 모두 필요
        raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, "시작/종료 시간은 필수입니다.") if link_data.start_at.blank? || link_data.end_at.blank?

        link_start = parse_datetime(link_data.start_at) # YYYY-MM-DDTHH:mm
        link_end  = parse_datetime(link_data.end_at)

        raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, "종료 시간은 시작 시간 이후여야 합니다.") if link_end <= link_start

      else
        # all-day 일정의 경우 날짜만 사용
        if link_data.start_at.blank? || link_data.end_at.blank?
          raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, "하루종일 일정은 날짜가 필요합니다.")
        end

        # 날짜만 들어와도 parse_datetime이 처리할 수 있게 함
        link_start = parse_datetime(link_data.start_at).beginning_of_day
        link_end = parse_datetime(link_data.end_at).end_of_day
      end

      ActiveRecord::Base.transaction do
        # 1. 일정 링크 생성
        link = ::ScheduleLink.create!(
          title: link_data.title,
          description: link_data.description,
          place_id: link_data.place_id.presence,
          place_text: link_data.place_text.presence,
          start_time: link_start,
          end_time: link_end,
          is_allday: link_data.is_allday || false,
          created_by: current_user_number
        )

        # 2. 일정 생성
        schedule = ::Schedule.create!(
          group_id: group.id,
          schedule_link_id: link.id,
          schedule_code: SecureRandom.hex(8),
          color: request.is_highlighted ? "highlight" : "normal",
          memo: request.comment,
          created_by: current_user_number
        )

        # 3. 응답 
        CreateScheduleResponse.new(
          schedule: Schedule.new(
            schedule_id: schedule.id,
            code: schedule.schedule_code,
            group_id: schedule.group_id,
            schedule_link_id: schedule.schedule_link_id,
          )
        )
      end

    rescue => e
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
    end

    # 2. 일정 목록 조회 (그룹 ID별)
   def get_schedule_list(request, call)
      current_user_number, role = RoleHelper.verify_user(call)
      current_user = ::User.find_by(user_number: current_user_number)

      allowed_group_ids = current_user ? current_user.groups.pluck(:id) : []
      target_group_ids = request.group_ids & allowed_group_ids

      if target_group_ids.empty?
        raise GRPC::BadStatus.new_status_exception(
          GRPC::Core::StatusCodes::NOT_FOUND,
          "조회 가능한 그룹이 없습니다."
        )
      end

      # 기간 필터링
      start_at = request.start_at.present? ? parse_datetime(request.start_at) : nil
      end_at  = request.end_at.present?  ? parse_datetime(request.end_at)   : nil

      schedules = AppSchedule
                    .includes(:schedule_link)
                    .joins(:schedule_link)
                    .where(group_id: target_group_ids)

      schedules = schedules.where("schedule_links.end_time >= ?", start_at) if start_at
      schedules = schedules.where("schedule_links.start_time <= ?", end_at) if end_at

      schedules = schedules.order(created_at: :desc)
      #그룹 색상 확인후 색상 가져오기
      group_colors = ::Group.where(id: target_group_ids)
                      .pluck(:id, :color_default)
                      .to_h

      schedule_responses = schedules.map do |s|
        link = s.schedule_link
        item_color = group_colors[s.group_id]  # TODO: color_default만  갖고오게됨 (하이라이트인경우 값을 무시할 수 있기때문에 변경해줘야함 )

        Bannote::Scheduleservice::Schedule::V1::Schedule.new(
          schedule_id: s.id,
          code: s.schedule_code,
          group_id: s.group_id,
          schedule_link_id: s.schedule_link_id,
          comment: s.memo,
          color: item_color, 
          created_at: Google::Protobuf::Timestamp.new(seconds: s.created_at.to_i),
          updated_at: s.updated_at ? Google::Protobuf::Timestamp.new(seconds: s.updated_at.to_i) : nil,
          deleted_at: s.deleted_at ? Google::Protobuf::Timestamp.new(seconds: s.deleted_at.to_i) : nil,
          created_by: s.created_by.to_i,
          updated_by: s.updated_by.to_i,
          deleted_by: s.deleted_by.to_i,

          schedule_link: link ? Bannote::Scheduleservice::Schedule::V1::ScheduleLink.new(
            schedule_link_id: link.id,
            title: link.title,
            place_id: link.place_id,
            place_text: link.place_text,
            description: link.description,
            start_at: link.start_time&.strftime("%Y-%m-%dT%H:%M"),
            end_at: link.end_time&.strftime("%Y-%m-%dT%H:%M"),
            is_allday: link.is_allday
          ) : nil
        )
      end

      GetScheduleListResponse.new(
        schedule_list_response: Bannote::Scheduleservice::Schedule::V1::ScheduleListResponse.new(
          schedules: schedule_responses
        )
      )
    end


    # 3. 일정 상세 조회
   def get_schedule(request, call)
      current_user_number, role = RoleHelper.verify_user(call)
      raise GRPC::BadStatus.new_status_exception(
        GRPC::Core::StatusCodes::UNAUTHENTICATED,
        "인증 실패"
      ) if current_user_number.nil?

      schedule = ::Schedule.includes(:group, :schedule_link)
                          .find_by(id: request.schedule_id)

      raise GRPC::BadStatus.new_status_exception(
        GRPC::Core::StatusCodes::NOT_FOUND,
        "일정을 찾을 수 없습니다."
      ) if schedule.nil?

      group = schedule.group

      is_member = ::UserGroup.exists?(user_id: current_user_number, group_id: group.id)
      unless is_member
        raise GRPC::BadStatus.new_status_exception(
          GRPC::Core::StatusCodes::PERMISSION_DENIED,
          "이 그룹에 속하지 않아 일정을 조회할 수 없습니다."
        )
      end

      link = schedule.schedule_link

      response_link =
        if link
          Bannote::Scheduleservice::Schedule::V1::ScheduleLink.new(
            schedule_link_id: link.id,
            title: link.title,
            place_id: link.place_id,
            place_text: link.place_text,
            description: link.description,
            start_at: link.start_time&.strftime("%Y-%m-%dT%H:%M"),
            end_at: link.end_time&.strftime("%Y-%m-%dT%H:%M"),
            is_allday: link.is_allday
          )
        else
          nil
        end

      Bannote::Scheduleservice::Schedule::V1::GetScheduleResponse.new(
        schedule: Bannote::Scheduleservice::Schedule::V1::Schedule.new(
          schedule_id: schedule.id,
          code: schedule.schedule_code,
          group_id: schedule.group_id,
          schedule_link_id: schedule.schedule_link_id,
          comment: schedule.memo,
          color: schedule.color,
          created_by: schedule.created_by.to_i,
          updated_by: schedule.updated_by.to_i,
          deleted_by: schedule.deleted_by.to_i,
          created_at: schedule.created_at ?
            Google::Protobuf::Timestamp.new(seconds: schedule.created_at.to_i) : nil,

          updated_at: schedule.updated_at ?
            Google::Protobuf::Timestamp.new(seconds: schedule.updated_at.to_i) : nil,

          deleted_at: schedule.deleted_at ?
            Google::Protobuf::Timestamp.new(seconds: schedule.deleted_at.to_i) : nil,

          updated_by: schedule.updated_by,
          deleted_by: schedule.deleted_by,

          schedule_link: response_link
        )
      )
    end


    # 4. 일정 수정
  def update_schedule(request, call)
    current_user_number, role = RoleHelper.verify_user(call)

    schedule = ::Schedule.includes(:schedule_link).find_by(id: request.schedule_id)
    raise GRPC::BadStatus.new_status_exception(
      GRPC::Core::StatusCodes::NOT_FOUND, "일정을 찾을 수 없습니다."
    ) if schedule.nil?

    link = schedule.schedule_link
    raise GRPC::BadStatus.new_status_exception(
      GRPC::Core::StatusCodes::NOT_FOUND,
      "이 일정에는 스케줄링크가 없습니다."
    ) if link.nil?

    group = schedule.group
    if group.group_type_id.in?([1, 2])
      unless RoleHelper.has_authority?(role, "TA")
        raise GRPC::BadStatus.new_status_exception(
          GRPC::Core::StatusCodes::PERMISSION_DENIED,
          "정규 수업 그룹의 일정은 조교 이상만 수정 가능합니다."
        )
      end
    else
      is_member = ::UserGroup.exists?(user_id: current_user_number, group_id: group.id)
      unless is_member
        raise GRPC::BadStatus.new_status_exception(
          GRPC::Core::StatusCodes::PERMISSION_DENIED,
          "이 그룹에 속하지 않아 일정을 수정할 수 없습니다."
        )
      end
    end

    # Schedule 수정
    schedule.memo = request.comment.presence || schedule.memo
    schedule.color = request.is_highlighted ? "highlight" : "normal"
    schedule.updated_by = current_user_number

    # ScheduleLink 수정
    link_data = request.link

    if link_data
      is_all_day = link_data.is_allday || false

      old_start = link.start_time
      old_end   = link.end_time

      new_start = link_data.start_at.present? ? parse_datetime(link_data.start_at) : old_start
      new_end   = link_data.end_at.present?   ? parse_datetime(link_data.end_at)   : old_end

      if is_all_day
        new_start = new_start&.beginning_of_day
        new_end   = new_end&.end_of_day
      end

      if new_start && new_end && new_end <= new_start
        raise GRPC::BadStatus.new_status_exception(
          GRPC::Core::StatusCodes::INVALID_ARGUMENT,
          "종료 시간이 시작 시간보다 이후여야 합니다."
        )
      end

      link.update!({
        title: link_data.title.presence || link.title,
        place_id: link_data.place_id.presence || link.place_id,
        place_text: link_data.place_text.presence || link.place_text,
        description: link_data.description.presence || link.description,
        start_time: new_start,
        end_time:  new_end,
        is_allday: is_all_day,
      })
    end

    schedule.save!

    # 응답
    Bannote::Scheduleservice::Schedule::V1::UpdateScheduleResponse.new(
      schedule: Bannote::Scheduleservice::Schedule::V1::Schedule.new(
        schedule_id: schedule.id,
        code: schedule.schedule_code,
        group_id: schedule.group_id,
        schedule_link_id: schedule.schedule_link_id,
        comment: schedule.memo,
        color: schedule.color,
        created_by: schedule.created_by&.to_i,
        updated_by: schedule.updated_by&.to_i,
        deleted_by: schedule.deleted_by&.to_i,
        created_at: Google::Protobuf::Timestamp.new(seconds: schedule.created_at.to_i),
        updated_at: Google::Protobuf::Timestamp.new(seconds: schedule.updated_at.to_i),

        schedule_link: Bannote::Scheduleservice::Schedule::V1::ScheduleLink.new(
          schedule_link_id: link.id,
          title: link.title,
          place_id: link.place_id,
          place_text: link.place_text,
          description: link.description,
          start_at: link.start_time&.strftime("%Y-%m-%dT%H:%M"),
          end_at: link.end_time&.strftime("%Y-%m-%dT%H:%M"),
          is_allday: link.is_allday
        )
      )
    )
  end

  
  #5. schedule 삭제
  def delete_schedule(request, call)
    current_user_number, role = RoleHelper.verify_user(call)
    raise GRPC::BadStatus.new_status_exception(
      GRPC::Core::StatusCodes::UNAUTHENTICATED, "인증 실패"
    ) if current_user_number.nil?

    schedule = ::Schedule.includes(:group, :schedule_link).find_by(id: request.schedule_id)
    raise GRPC::BadStatus.new_status_exception(
      GRPC::Core::StatusCodes::NOT_FOUND, "일정을 찾을 수 없습니다."
    ) if schedule.nil?

    group = schedule.group

    # 권한 체크
    if group.group_type_id.in?([1, 2])
      unless RoleHelper.has_authority?(role, "TA")
        raise GRPC::BadStatus.new_status_exception(
          GRPC::Core::StatusCodes::PERMISSION_DENIED,
          "정규/긴급 그룹의 일정은 조교 이상만 삭제할 수 있습니다."
        )
      end
    else
      is_member = ::UserGroup.exists?(user_id: current_user_number, group_id: group.id)
      unless is_member
        raise GRPC::BadStatus.new_status_exception(
          GRPC::Core::StatusCodes::PERMISSION_DENIED,
          "이 그룹에 속하지 않아 일정을 삭제할 수 없습니다."
        )
      end
    end

    ActiveRecord::Base.transaction do
      # 1) 스케줄링크 soft delete
      if schedule.schedule_link.present?
        schedule.schedule_link.update!(
          deleted_at: Time.current,
          deleted_by: current_user_number
        )
      end

      # 2) 스케줄 soft delete
      schedule.update!(
        deleted_at: Time.current,
        deleted_by: current_user_number
      )
    end

    Bannote::Scheduleservice::Schedule::V1::DeleteScheduleResponse.new(success: true)

  rescue => e
    raise GRPC::BadStatus.new_status_exception(
      GRPC::Core::StatusCodes::INTERNAL,
      "일정 삭제 실패: #{e.message}"
    )
  end
    # 개인 그룹 그룹은 등록되어있지만 스케줄링크는 안들고있을경우
    def delete_schedule_link(request, call)
      current_user_number, role = RoleHelper.verify_user(call)
      raise GRPC::BadStatus.new_status_exception(
        GRPC::Core::StatusCodes::UNAUTHENTICATED, "인증 실패"
      ) if current_user_number.nil?

      schedule = ::Schedule.includes(:group, :schedule_link).find_by(id: request.schedule_id)
      raise GRPC::BadStatus.new_status_exception(
        GRPC::Core::StatusCodes::NOT_FOUND, "일정을 찾을 수 없습니다."
      ) if schedule.nil?

      group = schedule.group

      # 개인그룹만 링크 삭제 허용
      unless group.group_type_id == 3
        raise GRPC::BadStatus.new_status_exception(
          GRPC::Core::StatusCodes::PERMISSION_DENIED,
          "정규 수업 그룹에서는 스케줄링크만 삭제할 수 없습니다."
        )
      end

      link = schedule.schedule_link
      raise GRPC::BadStatus.new_status_exception(
        GRPC::Core::StatusCodes::NOT_FOUND,
        "스케줄링크가 없습니다."
      ) if link.nil?

      ActiveRecord::Base.transaction do
        # soft delete
        link.update!(
          deleted_at: Time.current,
          deleted_by: current_user_number
        )

        # 스케줄에서 링크 연결 제거
        schedule.update!(schedule_link_id: nil)
      end

      Bannote::Scheduleservice::Schedule::V1::DeleteScheduleLinkResponse.new(success: true)

    rescue => e
      raise GRPC::BadStatus.new_status_exception(
        GRPC::Core::StatusCodes::INTERNAL,
        "링크 삭제 실패: #{e.message}"
      )
    end
  end
end
