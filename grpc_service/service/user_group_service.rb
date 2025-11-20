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

require_relative '../helpers/Role_helper'


module Bannote
  module Scheduleservice
    module User
      module V1
        class UserGroupServiceHandler < UserGroupService::Service
          # 1. 유저를 그룹에 추가
          def add_user_to_group(request, call)
            current_user_id, role = RoleHelper.verify_user(call)

            user = ::User.find_by(id: request.user_id)
            raise_bad(:NOT_FOUND, "User가 없습니다.") unless user

            group = ::Group.find_by(id: request.group_id)
            raise_bad(:NOT_FOUND, "Group이 없습니다.") unless group

            permission_label = group.group_permission&.permission.to_s

            case permission_label
            when "1" # 긴급
              unless ["TA", "PROFESSOR", "ADMIN"].include?(role)
                raise_bad(:PERMISSION_DENIED, "긴급 그룹에는 조교 이상만 유저를 추가할 수 있습니다.")
              end
            when "2", "3"
              # 정규 / 공개 → 학생도 추가 가능
            else
              raise_bad(:INVALID_ARGUMENT, "유효하지 않은 그룹 권한입니다.")
            end

            existing = ::UserGroup.find_by(user_id: request.user_id, group_id: request.group_id)
            raise_bad(:ALREADY_EXISTS, "이미 이 그룹에 속해 있습니다.") if existing

            relation = ::UserGroup.create!(
              user_id: user.id,
              group_id: group.id
            )

            AddUserToGroupResponse.new(
              user_id: relation.user_id,
              group_id: relation.group_id
            )
          end

          # 2. 특정 그룹의 전체 멤버 조회
          def get_users_in_group(request, call)
            current_user_id, role = RoleHelper.verify_user(call)

            group = ::Group.find_by(id: request.group_id)
            raise_bad(:NOT_FOUND, "Group이 존재하지 않습니다.") unless group

            permission_label = group.group_permission&.permission.to_s

            case permission_label
            when "1" # 긴급
              unless ["TA", "PROFESSOR", "ADMIN"].include?(role)
                raise_bad(:PERMISSION_DENIED, "긴급 그룹은 조교 이상만 조회할 수 있습니다.")
              end
            when "2", "3"
              # 정규 / 공개 → 누구나 조회 가능
            else
              raise_bad(:INVALID_ARGUMENT, "유효하지 않은 그룹 권한입니다.")
            end

            if group.users.empty?
              raise_bad(:NOT_FOUND, "이 그룹에는 유저가 없습니다.")
            end

            users = group.users.map do |u|
              AddUserToGroupResponse.new(
                user_id: u.id,
                group_id: group.id
              )
            end

            GetUsersInGroupResponse.new(
              users: users
            )
          end

          # 3. 특정 유저가 속한 모든 그룹 반환
          def get_groups_of_user(request, call)
            current_user_id, role = RoleHelper.verify_user(call)

            user = ::User.find_by(id: request.user_id)
            raise_bad(:NOT_FOUND, "유저를 찾지 못했습니다.") unless user

            # 학생은 본인만 조회 가능
            if role == "STUDENT" && current_user_id != user.id
              raise_bad(:PERMISSION_DENIED, "학생은 다른 유저의 그룹 목록을 조회할 수 없습니다.")
            end
            # 조교 이상 → 전체 조회 가능

            groups = user.groups.includes(:tags).map do |g|
              tag_responses = g.tags.map do |t|
                Bannote::Scheduleservice::Tag::V1::Tag.new(
                  tag_id: t.id,
                  name: t.name
                )
              end

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

            GetGroupsOfUserResponse.new(groups: groups)
          end

          # 4. 유저를 그룹에서 제거
          def remove_user_from_group(request, call)
            current_user_id, role = RoleHelper.verify_user(call)

            user = ::User.find_by(id: request.user_id)
            raise_bad(:NOT_FOUND, "User가 존재하지 않습니다.") unless user

            group = ::Group.find_by(id: request.group_id)
            raise_bad(:NOT_FOUND, "Group이 존재하지 않습니다.") unless group

            relation = ::UserGroup.find_by(user_id: request.user_id, group_id: request.group_id)
            raise_bad(:NOT_FOUND, "User는 이 그룹에 속해 있지 않습니다.") unless relation

            permission_label = group.group_permission&.permission.to_s

            case permission_label
            when "1" # 긴급 → 조교 이상만 제거 가능
              unless ["TA", "PROFESSOR", "ADMIN"].include?(role)
                raise_bad(:PERMISSION_DENIED, "긴급 그룹은 조교 이상만 멤버를 삭제할 수 있습니다.")
              end
            when "2", "3"
              # 학생은 본인 제거만 가능
              if role == "STUDENT" && current_user_id != user.id
                raise_bad(:PERMISSION_DENIED, "학생은 다른 유저를 제거할 수 없습니다.")
              end
            else
              raise_bad(:INVALID_ARGUMENT, "유효하지 않은 그룹 권한입니다.")
            end

            relation.destroy!

            RemoveUserFromGroupResponse.new(success: true)
          end

          # 공통 에러 함수
          private

          def raise_bad(code, message)
            raise GRPC::BadStatus.new_status_exception(
              GRPC::Core::StatusCodes.const_get(code),
              message
            )
          end

        end
      end
    end
  end
end
