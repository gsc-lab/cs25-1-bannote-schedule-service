require 'grpc'
require 'schedule_link/schedule_link_pb'
require 'schedule_link/schedule_link_service_services_pb'
require 'google/protobuf/well_known_types'
require_relative '../helpers/Role_helper'

# studyroom grpc import
# require 'reservation/reservation_pb'
# require 'reservation/service_services_pb'

module Bannote
  module Scheduleservice
    module ScheduleLink
      module V1
        class ScheduleLinkServiceHandler < Bannote::Scheduleservice::ScheduleLink::V1::ScheduleLinkService::Service

          # 1. 일정 링크 생성
          def create_schedule_link(request, call)
            start_time = Time.at(request.start_time.seconds)
            end_time   = Time.at(request.end_time.seconds)

            raise GRPC::InvalidArgument.new("제목은 필수입니다.") if request.title.to_s.strip.empty?
            user_id, role = TokenHelper.verify_token(call)
           
            unless RoleHelper.has_authority?(user_id, 4)
              raise GRPC::PermissionDenied.new("조교 이상만 일정을 생성할 수 있습니다.")
            end

            # 스터디룸 예약 연동
            # if request.place_text&.include?("스터디룸") || request.place_type == "studyroom"
            #   begin
            #     reservation_stub = Bannote::Studyroomservice::Reservation::V1::ReservationService::Stub.new(
            #       "studyroom_app:50051", :this_channel_is_insecure
            #     )
            #
            #     reservation_request = Bannote::Studyroomservice::Reservation::V1::CreateReservationRequest.new(
            #       room_id: request.place_id,
            #       group_id: 0,
            #       link_id: 0,
            #       start_time: Google::Protobuf::Timestamp.new(seconds: request.start_time.seconds),
            #       end_time:   Google::Protobuf::Timestamp.new(seconds: request.end_time.seconds),
            #       purpose: request.title,
            #       priority: :RESERVATION_PRIORITY_MEDIUM
            #     )
            #
            #     reservation_stub.create_reservation(reservation_request)
            #     puts "스터디룸 예약 성공 room_id=#{request.place_id}"
            #   rescue GRPC::BadStatus => e
            #     raise GRPC::FailedPrecondition.new("스터디룸 예약 실패: #{e.details}")
            #   end
            # end

            schedule_link = ::ScheduleLink.create!(
              title: request.title,
              place_id: request.place_id.zero? ? nil : request.place_id,
              place_text: request.place_text,
              description: request.description,
              start_time: start_time,
              end_time: end_time,
              is_allday: request.is_allday,
              created_by: user_id
            )

            link_object = Bannote::Scheduleservice::ScheduleLink::V1::ScheduleLink.new(
              link_id: schedule_link.id,
              schedule_id: request.schedule_id,
              title: schedule_link.title,
              place_id: schedule_link.place_id || 0,
              place_text: schedule_link.place_text || "",
              description: schedule_link.description,
              start_time: Google::Protobuf::Timestamp.new(seconds: schedule_link.start_time.to_i),
              end_time: Google::Protobuf::Timestamp.new(seconds: schedule_link.end_time.to_i),
              is_allday: schedule_link.is_allday,
              created_by: schedule_link.created_by,
              created_at: Google::Protobuf::Timestamp.new(seconds: schedule_link.created_at.to_i)
            )

            Bannote::Scheduleservice::ScheduleLink::V1::CreateScheduleLinkResponse.new(schedule_link: link_object)
          rescue => e
            raise GRPC::InvalidArgument.new("일정 링크 생성 실패: #{e.message}")
          end

          # 2. 일정 링크 조회
          def get_schedule_link(request, call)
            user_id, role = TokenHelper.verify_token(call)
          
            raise GRPC::Unauthenticated.new("인증 실패") if user_id.nil?

            link = ::ScheduleLink.find_by(id: request.link_id)
            raise GRPC::NotFound.new("일정 링크를 찾을 수 없습니다.") if link.nil?

            group = link.group
            raise GRPC::NotFound.new("그룹을 찾을 수 없습니다.") if group.nil?

            is_member = ::UserGroup.exists?(user_id: user_id, group_id: group.id)
            unless is_member
              raise GRPC::PermissionDenied.new("이 그룹에 속하지 않아 일정을 조회할 수 없습니다.")
            end

            link_object = Bannote::Scheduleservice::ScheduleLink::V1::ScheduleLink.new(
              link_id: link.id,
              title: link.title,
              description: link.description,
              start_time: Google::Protobuf::Timestamp.new(seconds: link.start_time.to_i),
              end_time: Google::Protobuf::Timestamp.new(seconds: link.end_time.to_i),
              is_allday: link.is_allday,
              created_by: link.created_by
            )

            Bannote::Scheduleservice::ScheduleLink::V1::GetScheduleLinkResponse.new(schedule_link: link_object)
          end

          # 3. 일정 링크 수정
          def update_schedule_link(request, call)
            user_id, role = TokenHelper.verify_token(call)
           
            raise GRPC::Unauthenticated.new("인증 실패") if user_id.nil?

            link = ::ScheduleLink.find_by(id: request.link_id)
            raise GRPC::NotFound.new("일정 링크를 찾을 수 없습니다.") if link.nil?

            group = link.group
            raise GRPC::NotFound.new("그룹을 찾을 수 없습니다.") if group.nil?

            if group.group_type_id == 1 ||group.group_type_id == 2
              unless RoleHelper.has_authority?(user_id, 4)
                raise GRPC::PermissionDenied.new("정규 수업 그룹은 조교 이상만 수정할 수 있습니다.")
              end
            else
              unless link.created_by == user_id
                raise GRPC::PermissionDenied.new("개인 그룹은 생성자만 수정할 수 있습니다.")
              end
            end

            start_time = Time.at(request.start_time.seconds)
            end_time   = Time.at(request.end_time.seconds)
            raise GRPC::InvalidArgument.new("종료 시간은 시작 시간 이후여야 합니다.") if end_time <= start_time

            link.update!(
              title: request.title.presence || link.title,
              place_text: request.place_text.presence || link.place_text,
              description: request.description.presence || link.description,
              start_time: start_time,
              end_time: end_time,
              is_allday: request.is_allday
            )

            link_object = Bannote::Scheduleservice::ScheduleLink::V1::ScheduleLink.new(
              link_id: link.id,
              title: link.title,
              description: link.description,
              start_time: Google::Protobuf::Timestamp.new(seconds: link.start_time.to_i),
              end_time: Google::Protobuf::Timestamp.new(seconds: link.end_time.to_i),
              is_allday: link.is_allday,
              created_by: link.created_by
            )

            Bannote::Scheduleservice::ScheduleLink::V1::UpdateScheduleLinkResponse.new(schedule_link: link_object)
          end

          # 4. 일정 링크 삭제
          def delete_schedule_link(request, call)
            user_id, role = TokenHelper.verify_token(call)
            raise GRPC::Unauthenticated.new("인증 실패") if user_id.nil?

            link = ::ScheduleLink.find_by(id: request.link_id)
            raise GRPC::NotFound.new("일정 링크를 찾을 수 없습니다.") if link.nil?

            group = link.group
            raise GRPC::NotFound.new("그룹을 찾을 수 없습니다.") if group.nil?

            if group.group_type_id == 1 || group.group_type_id == 2
              unless RoleHelper.has_authority?(user_id, 4)
                raise GRPC::PermissionDenied.new("정규 수업 그룹은 조교 이상만 삭제할 수 있습니다.")
              end
            else
              unless link.created_by == user_id
                raise GRPC::PermissionDenied.new("개인 그룹은 생성자만 삭제할 수 있습니다.")
              end
            end

            link.destroy!
            Bannote::Scheduleservice::ScheduleLink::V1::DeleteScheduleLinkResponse.new(success: true)
          rescue => e
            raise GRPC::Internal.new("일정 링크 삭제 실패: #{e.message}")
          end
        end
      end
    end
  end
end
