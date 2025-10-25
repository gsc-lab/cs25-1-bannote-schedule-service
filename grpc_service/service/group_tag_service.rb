require 'grpc'
require 'group_tag/group_tag_pb'
require 'group_tag/group_tag_service_services_pb'
require 'tag/tag_pb'
require 'google/protobuf/well_known_types'
require_relative '../helpers/token_helper'

module Bannote
  module Scheduleservice
    module GroupTag
      module V1
        class GroupTagServiceHandler < Bannote::Scheduleservice::GroupTag::V1::GroupTagService::Service

          # 1. 그룹에 태그 추가
          def add_tag_to_group(request, call)
            #1. 파싱
            group_id = request.group_id
            tag_id = request.tag_id
            #2. 유효성 검사
            raise GRPC::InvalidArgument.new("group_id는 필수 입니다")if group_id.nil? || group_id <= 0
            raise GRPC::InvalidArgument.new("tag_id는 필수입니다.") if tag_id.nil? || tag_id <= 0

            #3. 인증
            user_id,role =TokenHelper.verify_token(call)

            #4. 태그 여부
            group = ::Group.find_by(id: request.group_id)
            tag   = ::Tag.find_by(id: request.tag_id)
            # 못찾을경우
            raise GRPC::NotFound.new("그룹을 찾을 수 없습니다.") if group.nil?
            raise GRPC::NotFound.new("태그를 찾을 수 없습니다.") if tag.nil?
            #권한 검증
            if group.group_type_id == 1
              unless %w[assistant professor admin].include?(role)
                raise GRPC::PermissionDenind.new("정규수업은 조교이상 권한있습니다")
              end
            end


            group_tag = group.group_tags.create!(tag: tag)

            Bannote::Scheduleservice::GroupTag::V1::AddTagToGroupResponse.new(
              group_tag: Bannote::Scheduleservice::GroupTag::V1::GroupTag.new(
                group_id: group_tag.group_id,
                tag_id: group_tag.tag_id
              )
            )
          rescue => e
            raise GRPC::Internal.new("그룹에 태그 추가 실패: #{e.message}")
          end

          # 2. 그룹에 연결된 태그 목록 조회
          def get_tags_of_group(request, call)
            #1. 파싱
            group_id =request.group_id
            #2. 유효성 검사
            raise GRPC::InvalidArgument.new("groud_id는 필수 입니다")if group_id.nil? || group_id <= 0
            #3. 안중
            user_id, role = TokenHelper.verify_token(call)

            #4. 
            group = ::Group.find(request.group_id)
            tags = group.tags.map do |tag|
              Bannote::Scheduleservice::Tag::V1::Tag.new(
                tag_id: tag.id,
                name: tag.name,
                created_at: Google::Protobuf::Timestamp.new(seconds: tag.created_at.to_i)
              )
            end
            #5.응답
            Bannote::Scheduleservice::GroupTag::V1::GetTagsOfGroupResponse.new(tags: tags)
          rescue ActiveRecord::RecordNotFound
            raise GRPC::NotFound.new("그룹을 찾을 수 없습니다.")
          rescue => e
            raise GRPC::Internal.new("태그 조회 실패: #{e.message}")
          end

          # 3. 그룹에서 태그 삭제
          def remove_tag_from_group(request, call)
            #1. 파싱
            group_id = request.group_id
            tag_id = request.tag_id

            #2.유효성 검사
            raise GRPC::InvalidArgument.new("group_id는 필수입니다")if group_id.nil? || group_id <= 0
            raise GRPC::InvalidArgument.new("tag_id는 필수입니다")if tag_id.nil? || tag_id <=0

            #3.인증
            user_id,role =TokenHelper.verify_token(call)

            #4.권한 검증 
            group = ::Group.find_by(id: group_id)
            raise GRPC::NotFound.new("그룹을 찾을 수 없습니다") unless group

              unless %w[admin professor assistant].include?(role) || group.created_by == user_id
              raise GRPC::PermissionDenied.new("이 태그를 삭제할 권한이 없습니다.")
            end

            #5.태그 삭제못함
            group_tag = ::GroupTag.find_by(group_id: request.group_id,tag_id: request.tag_id)
            raise GRPC::NotFound.new("삭제할 태그 관계를 찾을 수 없습니다.") unless group_tag

            group_tag.destroy!

            #6.응답 생성
            Bannote::Scheduleservice::GroupTag::V1::RemoveTagFromGroupResponse.new(success: true)
          rescue GRPC::BadStatus => e
            raise e
          rescue => e
              raise GRPC::NotFound.new("삭제할 태그 관계를 찾을 수 없습니다.")
          end
        end
      end
    end
  end
end
