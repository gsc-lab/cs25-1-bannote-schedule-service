require 'grpc'
require 'group_tag/group_tag_pb'
require 'group_tag/group_tag_service_services_pb'
require 'tag/tag_pb'
require 'google/protobuf/well_known_types'

module Bannote
  module Scheduleservice
    module GroupTag
      module V1
        class GroupTagServiceHandler < Bannote::Scheduleservice::GroupTag::V1::GroupTagService::Service

          # 1. 그룹에 태그 추가
          def add_tag_to_group(request, _call)
            group_tag = ::GroupTag.create!(
              group_id: request.group_id,
              tag_id: request.tag_id
            )

            Bannote::Scheduleservice::GroupTag::V1::GroupTagResponse.new(
              group_id: group_tag.group_id,
              tag_id: group_tag.tag_id
            )
          rescue ActiveRecord::RecordNotFound => e
            raise GRPC::NotFound.new("그룹 또는 태그를 찾을 수 없습니다.")
          rescue => e
            raise GRPC::Internal.new("그룹에 태그 추가 실패: #{e.message}")
          end

          # 2. 그룹에 연결된 태그 목록 조회
          def get_tags_of_group(request, _call)
            group = ::Group.find(request.group_id)
            tags = group.tags.map do |tag|
              Bannote::Scheduleservice::Tag::V1::TagResponse.new(
                tag_id: tag.id,
                name: tag.name,
                created_by: tag.created_by || 0,
                created_at: Google::Protobuf::Timestamp.new(seconds: tag.created_at.to_i)
              )
            end

            Bannote::Scheduleservice::Tag::V1::TagListResponse.new(tags: tags)
          rescue ActiveRecord::RecordNotFound
            raise GRPC::NotFound.new("그룹을 찾을 수 없습니다.")
          end

          # 3. 그룹에서 태그 삭제
          def remove_tag_from_group(request, _call)
            group_tag = ::GroupTag.find_by(
              group_id: request.group_id,
              tag_id: request.tag_id
            )

            if group_tag
              group_tag.destroy
              Bannote::Scheduleservice::GroupTag::V1::RemoveTagFromGroupResponse.new(success: true)
            else
              raise GRPC::NotFound.new("삭제할 태그 관계를 찾을 수 없습니다.")
            end
          end
        end
      end
    end
  end
end
