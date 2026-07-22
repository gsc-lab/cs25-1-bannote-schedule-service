require 'grpc'
require 'group_tag/group_tag_pb'
require 'group_tag/group_tag_service_services_pb'
require 'tag/tag_pb'
require 'google/protobuf/well_known_types'
require_relative '../helpers/Role_helper'


module Bannote
  module Scheduleservice
    module GroupTag
      module V1
        class GroupTagServiceHandler < Bannote::Scheduleservice::GroupTag::V1::GroupTagService::Service
          # 1. 그룹에 태그 추가
          def add_tag_to_group(request, call)
            # 1. 파싱
            group_id = request.group_id
            tag_id = request.tag_id

            # 2. 유효성 검사
            raise GRPC::InvalidArgument.new("group_id는 필수 입니다") if group_id.nil? || group_id <= 0
            raise GRPC::InvalidArgument.new("tag_id는 필수입니다.") if tag_id.nil? || tag_id <= 0

            # 3. 인증
            user_id, role = RoleHelper.verify_user(call)

            # 4. DB 조회
            group = ::Group.find_by(id: group_id)
            tag = ::Tag.find_by(id: tag_id)

            raise GRPC::NotFound.new("그룹을 찾을 수 없습니다.") if group.nil?
            raise GRPC::NotFound.new("태그를 찾을 수 없습니다.") if tag.nil?

            # 권한 검증 (정규/긴급 = 조교 이상 / 개인 그룹 = 생성자 + 멤버)
            case group.group_type_id
            when 1, 2
              # 정규/긴급 → 조교 이상
              unless RoleHelper.has_authority?(role, "TA")
                raise GRPC::PermissionDenied.new("정규/긴급 그룹은 조교 이상 권한 필요")
              end

            when 3
              # 개인 그룹 → 생성자 또는 그룹 멤버
              member_ids = group.user_groups.pluck(:user_id)
              unless group.created_by == user_id || member_ids.include?(user_id)
                raise GRPC::PermissionDenied.new("개인 그룹은 생성자 또는 구성원만 태그를 추가할 수 있습니다.")
              end
            end
            # 태그 중복 방지 (필수)
            if group.group_tags.exists?(tag_id: tag_id)
              raise GRPC::AlreadyExists.new("해당 태그는 이미 그룹에 연결되어 있습니다.")
            end

            # UserGroup 자동 생성 
            unless ::UserGroup.exists?(user_id: user_id, group_id: group_id)
              ::UserGroup.create!(user_id: user_id, group_id: group_id, created_at: Time.current)
            end
            # 관계 생성
            group_tag = group.group_tags.create!(tag: tag)

            # 응답
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
            # 1. 파싱
            group_id = request.group_id

            # 2. 유효성 검사
            raise GRPC::InvalidArgument.new("groud_id는 필수 입니다") if group_id.nil? || group_id <= 0

             # 3. 안중
             user_id, role = RoleHelper.verify_user(call)

            # 4. db조회
            group = ::Group.find(request.group_id)
            tags = group.tags.map do |tag|
              Bannote::Scheduleservice::Tag::V1::Tag.new(
                tag_id: tag.id,
                name: tag.name,
                created_at: Google::Protobuf::Timestamp.new(seconds: tag.created_at.to_i)
              )
            end
            # 5.응답
            Bannote::Scheduleservice::GroupTag::V1::GetTagsOfGroupResponse.new(tags: tags)
          rescue ActiveRecord::RecordNotFound
            raise GRPC::NotFound.new("그룹을 찾을 수 없습니다.")
          rescue => e
            raise GRPC::Internal.new("태그 조회 실패: #{e.message}")
          end

          # 3. 그룹에서 태그 삭제
          def remove_tag_from_group(request, call)
            # 1. 파싱
            group_id = request.group_id
            tag_id = request.tag_id

            # 2.유효성 검사
            raise GRPC::InvalidArgument.new("group_id는 필수입니다") if group_id.nil? || group_id <= 0
            raise GRPC::InvalidArgument.new("tag_id는 필수입니다") if tag_id.nil? || tag_id <=0

             # 3.인증
             user_id, role = RoleHelper.verify_user(call)

            # 그룹 조회
            group = ::Group.find_by(id: group_id)
            raise GRPC::NotFound.new("그룹을 찾을 수 없습니다.") if group.nil?

            # 4.권한 검증
            case group.group_type_id
            when 1, 2
              # 긴급 / 정규 → 조교 이상
              unless RoleHelper.has_authority?(role, "TA")
                raise GRPC::PermissionDenied.new("정규/긴급 그룹은 조교 이상만 태그를 삭제할 수 있습니다.")
              end

            when 3
              # 개인 그룹 → 생성자만
              unless group.created_by == user_id
                raise GRPC::PermissionDenied.new("개인 그룹은 생성자만 태그를 삭제할 수 있습니다.")
              end
            end

            # 5.태그 관계 삭제
            group_tag = ::GroupTag.find_by(group_id: group_id, tag_id: tag_id)
            raise GRPC::NotFound.new("삭제할 태그 관계를 찾을 수 없습니다.") unless group_tag

            group_tag.destroy!

            # 6.응답 생성
            Bannote::Scheduleservice::GroupTag::V1::RemoveTagFromGroupResponse.new(success: true)
          rescue GRPC::BadStatus => e
            raise e
          rescue => e
            warn "#{e.backtrace.first(5)}"
            raise GRPC::Internal.new("그룹 태그 삭제 실패: #{e.message}")
          end
        end
      end
    end
  end
end
