require 'grpc'
require 'schedule_link/schedule_link_pb'
require 'schedule_link/schedule_link_service_services_pb'
require 'google/protobuf/well_known_types'

module Bannote
  module Scheduleservice
    module ScheduleLink
      module V1
        class ScheduleLinkServiceHandler < ScheduleLinkService::Service

          # 1. 일정 링크 생성
          def create_schedule_link(request, _call)
            schedule_link = ScheduleLink.create!(
              title: request.title,
              place_id: request.place_id.zero? ? nil : request.place_id,
              place_text: request.place_text,
              description: request.description,
              start_time: Time.at(request.start_time.seconds),
              end_time: Time.at(request.end_time.seconds),
              is_allday: request.is_allday,
              created_by: request.created_by
            )

            Schedule::ScheduleLinkResponse.new(
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
          rescue => e
            puts "Error creating schedule link: #{e.message}"
            raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
          end

          # 2. 일정 링크 조회
          def get_schedule_link(request, _call)
            link = ScheduleLink.find(request.link_id)

            Schedule::ScheduleLinkResponse.new(
              link_id: link.id,
              title: link.title,
              description: link.description,
              start_time: Google::Protobuf::Timestamp.new(seconds: link.start_time.to_i),
              end_time: Google::Protobuf::Timestamp.new(seconds: link.end_time.to_i),
              is_allday: link.is_allday,
              created_by: link.created_by
            )
          rescue ActiveRecord::RecordNotFound
            raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "ScheduleLink not found")
          end

          # 3. 일정 링크 수정
          def update_schedule_link(request, _call)
            link = ScheduleLink.find(request.link_id)
            link.update!(
              title: request.title.presence || link.title,
              place_text: request.place_text.presence || link.place_text,
              description: request.description.presence || link.description,
              start_time: request.start_time.seconds.zero? ? link.start_time : Time.at(request.start_time.seconds),
              end_time: request.end_time.seconds.zero? ? link.end_time : Time.at(request.end_time.seconds),
              is_allday: request.is_allday
            )

            Schedule::ScheduleLinkResponse.new(
              link_id: link.id,
              title: link.title,
              description: link.description,
              start_time: Google::Protobuf::Timestamp.new(seconds: link.start_time.to_i),
              end_time: Google::Protobuf::Timestamp.new(seconds: link.end_time.to_i),
              is_allday: link.is_allday
            )
          rescue ActiveRecord::RecordNotFound
            raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "ScheduleLink not found")
          rescue => e
            raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
          end

          # 4. 일정 링크 삭제
          def delete_schedule_link(request, _call)
            link = ScheduleLink.find_by(id: request.link_id)
            if link
              link.destroy
              Schedule::DeleteScheduleLinkResponse.new(success: true)
            else
              Schedule::DeleteScheduleLinkResponse.new(success: false)
            end
          rescue => e
            puts "Error deleting schedule link: #{e.message}"
            Schedule::DeleteScheduleLinkResponse.new(success: false)
          end

        end
      end
    end
  end
end
