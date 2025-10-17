# require 'grpc'
# require 'schedule_link/schedule_link_pb'
# require 'schedule_link/schedule_link_service_services_pb'
# require 'google/protobuf/well_known_types'

# module Bannote
#   module Scheduleservice
#     module ScheduleLink
#       module V1
#         class ScheduleLinkServiceHandler < ScheduleLinkService::Service

#           # 1. 일정 링크 생성
#           def create_schedule_link(request, _call)
#             schedule_link = ::ScheduleLink.create!(
#               title: request.title,
#               place_id: request.place_id.zero? ? nil : request.place_id,
#               place_text: request.place_text,
#               description: request.description,
#               start_time: Time.at(request.start_time.seconds),
#               end_time: Time.at(request.end_time.seconds),
#               is_allday: request.is_allday,
#               created_by: request.created_by
#             )

#             Bannote::Scheduleservice::ScheduleLink::V1::ScheduleLinkResponse.new(
#               link_id: schedule_link.id,
#               schedule_id: request.schedule_id,
#               title: schedule_link.title,
#               place_id: schedule_link.place_id || 0,
#               place_text: schedule_link.place_text || "",
#               description: schedule_link.description,
#               start_time: Google::Protobuf::Timestamp.new(seconds: schedule_link.start_time.to_i),
#               end_time: Google::Protobuf::Timestamp.new(seconds: schedule_link.end_time.to_i),
#               is_allday: schedule_link.is_allday,
#               created_by: schedule_link.created_by,
#               created_at: Google::Protobuf::Timestamp.new(seconds: schedule_link.created_at.to_i)
#             )
#           rescue => e
#             puts "Error creating schedule link: #{e.message}"
#             raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
#           end

#           # 2. 일정 링크 조회
#           def get_schedule_link(request, _call)
#             link = ::ScheduleLink.find(request.link_id)

#             Bannote::Scheduleservice::ScheduleLink::V1::ScheduleLinkResponse.new(
#               link_id: link.id,
#               title: link.title,
#               description: link.description,
#               start_time: Google::Protobuf::Timestamp.new(seconds: link.start_time.to_i),
#               end_time: Google::Protobuf::Timestamp.new(seconds: link.end_time.to_i),
#               is_allday: link.is_allday,
#               created_by: link.created_by
#             )
#           rescue ActiveRecord::RecordNotFound
#             raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "ScheduleLink not found")
#           end

#           # 3. 일정 링크 수정
#           def update_schedule_link(request, _call)
#             link = ::ScheduleLink.find(request.link_id)
#             link.update!(
#               title: request.title.presence || link.title,
#               place_text: request.place_text.presence || link.place_text,
#               description: request.description.presence || link.description,
#               start_time: request.start_time.seconds.zero? ? link.start_time : Time.at(request.start_time.seconds),
#               end_time: request.end_time.seconds.zero? ? link.end_time : Time.at(request.end_time.seconds),
#               is_allday: request.is_allday
#             )

#             Bannote::Scheduleservice::ScheduleLink::V1::ScheduleLinkResponse.new(
#               link_id: link.id,
#               title: link.title,
#               description: link.description,
#               start_time: Google::Protobuf::Timestamp.new(seconds: link.start_time.to_i),
#               end_time: Google::Protobuf::Timestamp.new(seconds: link.end_time.to_i),
#               is_allday: link.is_allday
#             )
#           rescue ActiveRecord::RecordNotFound
#             raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "ScheduleLink not found")
#           rescue => e
#             raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
#           end

#           # 4. 일정 링크 삭제
#           def delete_schedule_link(request, _call)
#             link = ::ScheduleLink.find_by(id: request.link_id)
#             if link
#               link.destroy
#               Bannote::Scheduleservice::ScheduleLink::V1::DeleteScheduleLinkResponse.new(success: true)
#             else
#               Bannote::Scheduleservice::ScheduleLink::V1::DeleteScheduleLinkResponse.new(success: false)
#             end
#           rescue => e
#             puts "Error deleting schedule link: #{e.message}"
#             Bannote::Scheduleservice::ScheduleLink::V1::DeleteScheduleLinkResponse.new(success: false)
#           end

#         end
#       end
#     end
#   end
# end


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
            schedule_link = ::ScheduleLink.create!(
              title: request.title,
              place_id: request.place_id.zero? ? nil : request.place_id,
              place_text: request.place_text,
              description: request.description,
              start_time: Time.at(request.start_time.seconds),
              end_time: Time.at(request.end_time.seconds),
              is_allday: request.is_allday,
              created_by: request.created_by
            )

            # 수정된 부분: ScheduleLink 객체를 먼저 생성합니다.
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

            # 수정된 부분: .proto에 정의된 CreateScheduleLinkResponse로 감싸서 반환합니다.
            Bannote::Scheduleservice::ScheduleLink::V1::CreateScheduleLinkResponse.new(schedule_link: link_object)
          rescue => e
            puts "Error creating schedule link: #{e.message}"
            raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
          end

          # 2. 일정 링크 조회
          def get_schedule_link(request, _call)
            link = ::ScheduleLink.find(request.link_id)

            # 수정된 부분: ScheduleLink 객체를 먼저 생성합니다.
            link_object = Bannote::Scheduleservice::ScheduleLink::V1::ScheduleLink.new(
              link_id: link.id,
              title: link.title,
              description: link.description,
              start_time: Google::Protobuf::Timestamp.new(seconds: link.start_time.to_i),
              end_time: Google::Protobuf::Timestamp.new(seconds: link.end_time.to_i),
              is_allday: link.is_allday,
              created_by: link.created_by
              # 참고: Get 응답에 필요한 다른 필드들도 채워주어야 합니다.
            )

            # 수정된 부분: GetScheduleLinkResponse로 감싸서 반환합니다.
            Bannote::Scheduleservice::ScheduleLink::V1::GetScheduleLinkResponse.new(schedule_link: link_object)
          rescue ActiveRecord::RecordNotFound
            raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "ScheduleLink not found")
          end

          # 3. 일정 링크 수정
          def update_schedule_link(request, _call)
            link = ::ScheduleLink.find(request.link_id)
            link.update!(
              title: request.title.presence || link.title,
              place_text: request.place_text.presence || link.place_text,
              description: request.description.presence || link.description,
              start_time: request.start_time.seconds.zero? ? link.start_time : Time.at(request.start_time.seconds),
              end_time: request.end_time.seconds.zero? ? link.end_time : Time.at(request.end_time.seconds),
              is_allday: request.is_allday
            )

            # 수정된 부분: ScheduleLink 객체를 먼저 생성합니다.
            link_object = Bannote::Scheduleservice::ScheduleLink::V1::ScheduleLink.new(
              link_id: link.id,
              title: link.title,
              description: link.description,
              start_time: Google::Protobuf::Timestamp.new(seconds: link.start_time.to_i),
              end_time: Google::Protobuf::Timestamp.new(seconds: link.end_time.to_i),
              is_allday: link.is_allday
              # 참고: Update 응답에 필요한 다른 필드들도 채워주어야 합니다.
            )
            
            # 수정된 부분: UpdateScheduleLinkResponse로 감싸서 반환합니다.
            Bannote::Scheduleservice::ScheduleLink::V1::UpdateScheduleLinkResponse.new(schedule_link: link_object)
          rescue ActiveRecord::RecordNotFound
            raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "ScheduleLink not found")
          rescue => e
            raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
          end

          # 4. 일정 링크 삭제 (이 코드는 원래도 문제가 없었습니다)
          def delete_schedule_link(request, _call)
            link = ::ScheduleLink.find_by(id: request.link_id)
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