require 'grpc'
require 'schedule_link/schedule_link_pb'
require 'schedule_link/schedule_link_service_services_pb'
require 'google/protobuf/well_known_types'
require_relative '../helpers/token_helper'

#studyroom grpc import
require 'reservation/reservation_pb'
require 'reservation/service_services_pb'


module Bannote
  module Scheduleservice
    module ScheduleLink
      module V1
        class ScheduleLinkServiceHandler < ScheduleLinkService::Service

          # 1. 일정 링크 생성
          def create_schedule_link(request, call)
            #파싱
            start_time = Time.at(request.start_time.seconds)
            end_time = Time.at(request.end_time.seconds)

            # 유효성
            if request.title.to_s.strip.empty?
              raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT,"제목은 필수 입니다 ")
            end
            if request.start_time.nil? || request.end_time.nil?
              raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT,"시간 입력은 필수 입니다 ")
            end

            # jwt 인증 
            user_id,role = TokenHelper.verify_token(call)

            # 권한 검증
            unless %w[admin professor assistant].include?(role)
              raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::PERMISSION_DENIED, "권한이 없습니다.")
            end
            # 하드웨어 실습실인경우 grpc로 호출 
            if request.place_text&.include?("스터디룸") || request.place_type == "studyroom"
              #1. grpc 클라이언트 생성
            reservation_stub = Bannote::Studyroomservice::Reservation::V1::ReservationService::Stub.new(
              "studyroom_app:50051", :this_channel_is_insecure
            )

            #2. 요청 생성
            reservation_request = Bannote::Studyroomservice::Reservation::V1::CreateReservationRequest.new(
              room_id: request.place_id,
              group_id: 0,
              link_id: 0,
              start_time: Google::Protobuf::Timestamp.new(seconds: request.start_time.seconds),
              end_time:   Google::Protobuf::Timestamp.new(seconds: request.end_time.seconds),
              purpose: request.title,
              priority: :RESERVATION_PRIORITY_MEDIUM
            )
            #3. GRPC 호출
            begin
              reservation_response = reservation_stub.create_reservation(reservation_request)
              puts "shedulelink 성공  room_id =#{request.place_id}"
              puts "예약성공 room_id=#{request.place_id}"
            rescue GRPC::BadStatus => e
              puts "shedulelink 실패 =#{e.details} "
              raise GRPC::BadStatus.new_status_exception(
                GRPC::Core::StatusCodes::FAILED_PRECONDITION,
                puts "shedulelink 실패 =#{e.details} "
                puts "하드웨어 실습실 예약 실패: #{e.details}"
              )
            end
          end

          # 일정 링크 생성
            schedule_link = ::ScheduleLink.create!(
              title: request.title,
              place_id: request.place_id.zero? ? nil : request.place_id,
              place_text: request.place_text,
              description: request.description,
              start_time: Time.at(request.start_time.seconds),
              end_time: Time.at(request.end_time.seconds),
              is_allday: request.is_allday,
              created_by: user_id
            )

            link_object = Bannote::Scheduleservice::ScheduleLink::V1::ScheduleLink.new(
              link_id: schedule_link.id,
              schedule_id: request.schedule_id, # schedule_id는 request에서 가져와야 합니다.
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
            puts "Error creating schedule link: #{e.message}"
            raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
          end

          # 2. 일정 링크 조회
          def get_schedule_link(request, call)
            user = ::User.find_by(id:user_id)
            user_groups = user.groups.pluck(:id)

            # 인증
            user_id,role = TokenHelper.verify_token(call)
            raise GRPC::BadStatus.new_stauts_exception(GRPC::Core::StatusCodes::UNAUTHENTICATED, "인증 실패") if user_id.nil?
            
            link = ::ScheduleLink.find(request.link_id)
            raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "일정을 찾을 수 없습니다.") if link.nil?
            
            # 권한 검증
            unless user_group.include?(link.group_id) || %w[admin professor assistant].include?(role)
              raise GRPC::BadStauts.new_status_exception(
                GRPC::Core::StatusCodes::PERISSOION_DENIED,
                "해당 그룹에 속하지 않아 일정을 조회할 수 없습니다"
              )
            end

            #응답반환
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
          rescue ActiveRecord::RecordNotFound
            raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "ScheduleLink not found")
          end

          # 3. 일정 링크 수정
          def update_schedule_link(request, call)
            #1.jwt
            user_id, role = TokenHelper.verify_token(call)
            raise GRPC::BadStauts.new_status_exception(RPC::Core::StatusCodes::UNAUTHENTICATED, "인증 실패") if use_id.nil?
            # 일정조회
            link = ::ScheduleLink.find(request.link_id)
              raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "일정을 찾을 수 없습니다.") if link.nil?

            if link.group_id_type ==1
              unless %w[admin professor assistant ].include?(role) || link.created_by == user_id
                raise PEMISSION_DENIED
              end
            elsif link.group_id_type == 2
              user = :: User.find_by(id: user_id)
              user_groups = user.groups.pluck(:id)
              unless user_groups.include?(link.group_id)
                raise PEMISSION_DENIED
              end
            end

            # 시간 검증
            start_time = Time.at(request.start_time.seconds)
            end_time = Time.at(request.end_time.seconds)
            if end_time <= start_time
              raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, "종료 시간은 시작 시간 이후여야 합니다.")
            end

            # 일정 수정
            link.update!(
              title: request.title.presence || link.title,
              place_text: request.place_text.presence || link.place_text,
              description: request.description.presence || link.description,
              start_time: request.start_time.seconds.zero? ? link.start_time : Time.at(request.start_time.seconds),
              end_time: request.end_time.seconds.zero? ? link.end_time : Time.at(request.end_time.seconds),
              is_allday: request.is_allday
            )
            # 응답
            link_object = Bannote::Scheduleservice::ScheduleLink::V1::ScheduleLink.new(
              link_id: link.id,
              title: link.title,
              description: link.description,
              start_time: Google::Protobuf::Timestamp.new(seconds: link.start_time.to_i),
              end_time: Google::Protobuf::Timestamp.new(seconds: link.end_time.to_i),
              is_allday: link.is_allday
              created_by: link.created_by
            )
            
          Bannote::Scheduleservice::ScheduleLink::V1::UpdateScheduleLinkResponse.new(schedule_link: link_object)
          rescue ActiveRecord::RecordNotFound
            raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "ScheduleLink not found")
          rescue => e
            raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
          end

          # 4. 일정 링크 삭제 
          def delete_schedule_link(request, call)
            #인증
            user_id, role = TokenHelper.verify_token(call)
             raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::UNAUTHENTICATED, "인증 실패") if user_id.nil?

            #일정 조회
            link = ::ScheduleLink.find_by(id: request.link_id)
             raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "일정을 찾을 수 없습니다.") if link.nil?

            #권한 검사
            case group.group_type_id
            when 1 # 정규 수업
              unless %w[assistant professor admin].include?(role)
                raise GRPC::PermissionDenied.new("정규 수업 그룹은 조교이상의 권한만 삭제 할 수있습니다")
              end
            when 2 
              unless group.created_by == user.id
                raise GRPC::InvalidArgument.new("유효하지않은 group_type_id입니다")
              end
              
            if link
              link.destroy
              Bannote::Scheduleservice::ScheduleLink::V1::DeleteScheduleLinkResponse.new(success: true)
            else
              Bannote::Scheduleservice::ScheduleLink::V1::DeleteScheduleLinkResponse.new(success: false)
            end
          rescue => e
            puts "Error deleting schedule link: #{e.message}"
            Bannote::Scheduleservice::ScheduleLink::V1::DeleteScheduleLinkResponse.new(success: false)
          end
        end
      end
    end
  end
end