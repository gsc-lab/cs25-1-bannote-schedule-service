require 'grpc'
require 'google/protobuf/well_known_types'

# UserGroup proto
require 'user_group/user_group_pb'
require 'user_group/user_group_service_pb'
require 'user_group/user_group_service_services_pb'

# Group proto
require 'group/group_pb'
require 'group/group_service_pb'
require 'group/group_service_services_pb'

# Tag proto
require 'tag/tag_pb'
require 'tag/tag_service_pb'
require 'tag/tag_service_services_pb'

module Bannote
  module Scheduleservice
    module User
      module V1
        class UserGroupServiceHandler < UserGroupService::Service
          #1. 특정 유저를 특정 그룹에 추가
          def add_user_to_group(request, _call)
            #유저 존재하는지 확인
            user = ::User.find_by(id: request.user_id)
            raise GRPC::NotFound.new("User가 없습니다") if user.nil?

            #그룹이 존재하는지 확인
            group = ::Group.find_by(id: request.group_id)
            raise GRPC::NotFound.new("Group이 없습니다") if group.nil?

            #속하고 있는지 없는지 확인
            existing = ::UserGroup.find_by(user_id: request.user_id,group_id: request.group_id)
            if existing
              raise GRPC::AlreadyExists.new("이미 이 그룹에 속해 있습니다")
            end

            # UserGroup 테이블에 관계 생성
            relation = ::UserGroup.create!(
              user_id: user.id,
              group_id: group.id
            )

            # proto 응답 객체 생성
            Bannote::Scheduleservice::User::V1::AddUserToGroupResponse.new(
              user_id: relation.user_id,
              group_id: relation.group_id
            )
          end

          #2. 특정 그룹에 속한 모든 유저 목록 반환
          def get_users_in_group(request, _call)
            group = ::Group.find_by(id: request.group_id)
            #그룹 없음
            if group.nil?
              raise GRPC::NotFound.new("group이 존재 하지않습니다")
            end
            
            # 유저 없음
            if group.users.empty?
              raise GRPC::NotFound.new("이 그룹에는 유저가 없습니다")
            end

            users = group.users.map do |u|
              Bannote::Scheduleservice::User::V1::AddUserToGroupResponse.new(
                user_id: u.id,
                group_id: group.id
              )
            end

            Bannote::Scheduleservice::User::V1::GetUsersInGroupResponse.new(
              users: users
            )
          end
   
          # 3. 특정 유저가 속한 모든 그룹 + group_tags까지 반환
          def get_groups_of_user(request, _call)
            user = ::User.find_by(id: request.user_id)
            raise GRPC::NotFound.new("유저를 찾지못했습니다") if user.nil?

             # 유저의 그룹 목록 조회 (그룹이 없어도 [] 이므로 정상 처리)
            groups = user.groups.includes(:tags).map do |g|
              # 태그 변환
              tag_responses = g.tags.map do |t|
                Bannote::Scheduleservice::Tag::V1::Tag.new(
                  tag_id: t.id,
                  name: t.name
                )
              end

              # 그룹 변환
              Bannote::Scheduleservice::Group::V1::Group.new(
                group_id: g.id,
                group_type_id: g.group_type_id,
                group_name: g.group_name,
                group_description: g.group_description,
                is_public: g.is_public,
                is_published: g.is_published,
                color_default: g.color_default,
                color_highlight: g.color_highlight,
                tags: tag_responses
              )
            end
            #  GroupListResponse 넣으면 안 됨 배열만 넣어야 한다.
            Bannote::Scheduleservice::User::V1::GetGroupsOfUserResponse.new(
              groups: groups  # 배열만 넣는다
            )
          end
  
          #4.  유저를 그룹에서 제거
          def remove_user_from_group(request, _call)
            #유저 확인
            user = ::User.find_by(id: request.user_id)
            if user.nil?
              raise GRPC::BadStatus.new_status_exception(
                GRPC::Core::StatusCodes::NOT_FOUND,
                "User가 존재하지 않습니다"
              )
            end
            #그룹 확인
            group = ::Group.find_by(id: request.group_id)
            if group.nil?
              raise GRPC::BadStatus.new_status_exception(
                GRPC::Core::StatusCodes::NOT_FOUND,
                "Group이 존재하지 않습니다"
              )
            end
            #관계 존재 여부확인
            relation = ::UserGroup.find_by(
              user_id: request.user_id,
              group_id: request.group_id
            )
            if relation.nil?
              raise GRPC::BadStatus.new_status_exception(
                GRPC::Core::StatusCodes::NOT_FOUND,
                "User는 이 그룹에 속해 있지 않습니다"
              )
            end
            # 삭제 처리
            relation.destory

            #성공응답 
            Bannote::Scheduleservice::User::V1::RemoveUserFromGroupResponse.new(
              success: true
            )
          end
        end
      end
    end
  end
end
