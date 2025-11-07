require 'grpc'
require 'google/protobuf/well_known_types'
require_relative '../helpers/Role_helper'

module Bannote::Scheduleservice::User::V1
  class UserGroupServiceHandler < Bannote::Scheduleservice::User::V1::UserGroupService::Service

    # 1. 그룹에 유저 추가
    def add_user_to_group(request, call)
      #1. 파싱
      user = User.find(request.user_id)
      group = Group.find(request.group_id)

      relation = UserGroup.create!(
        user_id: user.id,
        group_id: group.id
      )

      Schedule::UserGroupResponse.new(
        user_id: relation.user_id,
        group_id: relation.group_id,
        created_at: Google::Protobuf::Timestamp.new(seconds: relation.created_at.to_i)
      )
    rescue ActiveRecord::RecordNotFound => e
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, e.message)
    rescue => e
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
    end

    # 2. 그룹 내 유저 목록 조회
    def get_users_in_group(request, _call)
      group = Group.find(request.group_id)
      users = group.users.map do |u|
        Schedule::UserGroupResponse.new(
          user_id: u.id,
          group_id: group.id,
          created_at: Google::Protobuf::Timestamp.new(seconds: Time.now.to_i)
        )
      end

      Schedule::UserGroupListResponse.new(users: users)
    rescue ActiveRecord::RecordNotFound
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "Group not found")
    end

    # 3. 유저가 속한 그룹 목록 조회
    def get_groups_of_user(request, _call)
      user = User.find(request.user_id)
      groups = user.groups.includes(:tags)

      group_responses = groups.map do |g|
        tags = g.tags.map do |t|
          Schedule::TagResponse.new(
            tag_id: t.id,
            name: t.name,
            created_by: t.created_by,
            created_at: Google::Protobuf::Timestamp.new(seconds: t.created_at.to_i)
          )
        end

        Schedule::GroupResponse.new(
          group_id: g.id,
          group_type_id: g.group_type_id,
          group_name: g.group_name,
          group_description: g.group_description,
          is_public: g.is_public,
          is_published: g.is_published,
          color_default: g.color_default,
          color_highlight: g.color_highlight,
          created_by: g.created_by,
          created_at: Google::Protobuf::Timestamp.new(seconds: g.created_at.to_i),
          tags: tags
        )
      end

      Schedule::GroupListResponse.new(groups: group_responses)
    rescue ActiveRecord::RecordNotFound
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::NOT_FOUND, "User not found")
    end

    # 4. 그룹에서 유저 제거
    def remove_user_from_group(request, _call)
      relation = UserGroup.find_by(user_id: request.user_id, group_id: request.group_id)
      if relation
        relation.destroy
        Schedule::RemoveUserFromGroupResponse.new(success: true)
      else
        Schedule::RemoveUserFromGroupResponse.new(success: false)
      end
    rescue => e
      puts "Error removing user from group: #{e.message}"
      Schedule::RemoveUserFromGroupResponse.new(success: false)
    end
  end
end
