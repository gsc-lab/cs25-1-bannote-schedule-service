require 'grpc'
require 'tag/tag_pb'
require 'tag/tag_service_pb'  
require 'tag/tag_service_services_pb'
require 'common_pb'
require_relative '../helpers/Role_helper'


module Bannote::Scheduleservice::Tag::V1
  class TagServiceHandler < Bannote::Scheduleservice::Tag::V1::TagService::Service
    # 1. 태그 생성
    def create_tag(request, call)
      # 1.파싱
      name = request.name&.strip
      # 2. 유효성 검사
      raise GRPC::InvalidArgument.new("태그 이름은 필수입니다") if name.nil? || name.empty?
      user_id, role = RoleHelper.verify_user(call)

      # 관리자 이상만 생성 가능
      unless RoleHelper.has_authority?(role, 4)
        raise GRPC::PermissionDenied.new("태그 생성은 조교님 이y상 가능합니다.")
      end

      # tag이름 중복시
      if ::Tag.exists?(name: name)
        raise GRPC::AlreadyExists.new("이미 존재하는 태그입니다.")
      end

      # 5.생성
      tag = ::Tag.create!(name: request.name, created_by: user_id)

      # 6. 응답 반환
      Bannote::Scheduleservice::Tag::V1::CreateTagResponse.new(tag: build_tag_response(tag))
    rescue => e
      raise GRPC::Internal.new("태그 생성 실패: #{e.message}")
    end
    
    #단일 태그 조회
    def get_tag(request, call)
      user_id, role = RoleHelper.verify_user(call)

      tag_id = request.tag_id
      raise GRPC::InvalidArgument.new("tag_id는 반드시 필요합니다.") if tag_id.nil? || tag_id <= 0

      tag = ::Tag.find_by(id: tag_id)
      raise GRPC::NotFound.new("태그를 찾을 수 없습니다.") unless tag

      # 학생 권한: 공개 그룹 태그인지 체크
      unless RoleHelper.has_authority?(role, 4)
        is_public = ::Group
              .joins(:group_tags)
              .where(is_public: true, group_tags: { tag_id: tag.id })
              .exists?
              
        raise GRPC::PermissionDenied.new("공개 태그만 조회할 수 있습니다.") unless is_public
      end

      Bannote::Scheduleservice::Tag::V1::GetTagResponse.new(
        tag: build_tag_response(tag)
      )

    rescue => e
      raise GRPC::Internal.new("태그 조회 실패: #{e.message}")
    end

    # 3. 태그 목록 조회
    def get_tag_list(request, call)
      user_id, role = RoleHelper.verify_user(call)

      page = request.page > 0 ? request.page : 1
      per_page = request.per_page > 0 ? request.per_page : 10

      # 권한에 따라 조회 범위 구분
      if RoleHelper.has_authority?(role, 4)
        tags = ::Tag.all
      else
        tags = ::Tag.joins(:groups)
                    .where(groups: { is_public: true })
                    .distinct
      end
      total_count = tags.count
      total_pages = (total_count / per_page.to_f).ceil

      paginated_tags = tags
                        .order(created_at: :desc)
                        .limit(per_page)
                        .offset((page - 1) * per_page)

      grpc_tags = paginated_tags.map { |t| build_tag_response(t) }

      Bannote::Scheduleservice::Tag::V1::GetTagListResponse.new(
        tag_list_response: Bannote::Scheduleservice::Tag::V1::TagListResponse.new(
          tags: grpc_tags,
          page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: total_pages
        )
      )
    end

    #태그 상세 조회
   def get_many_tags(request, call)
      user_id, role = RoleHelper.verify_user(call)

      tag_ids = request.tag_ids
      raise GRPC::InvalidArgument.new("tag_ids는 필수입니다.") if tag_ids.empty?

      # 문자열로 오더라도 int 변환해서 안전하게 맞춤
      tag_ids = tag_ids.map(&:to_i)

      tags = ::Tag.where(id: tag_ids)

      grpc_tags = tags.map { |t| build_tag_response(t) }
      Bannote::Scheduleservice::Tag::V1::GetManyTagsResponse.new(
        tags: grpc_tags
      )
    end

    # 4. 태그 삭제
    def delete_tag(request, call)
      # 1.메타데이터
      user_id, role = RoleHelper.verify_user(call)

      # 2. 파싱
      tag_id = request.tag_id
      raise GRPC::InvalidArgument.new("tag_id는 필수입니다") if tag_id.nil? || tag_id <=0

      # 3. 권한검사
      unless RoleHelper.has_authority?(role, 4)
        raise GRPC::PermissionDenied.new("태그삭제는 조교 이상만 가능합니다")
      end

      tag = ::Tag.find_by(id: tag_id)
      raise GRPC::NotFound.new("삭제할 태그를 찾을 수 없습니다.") unless tag

      tag.destroy
        Bannote::Scheduleservice::Tag::V1::DeleteTagResponse.new(success: true)

    rescue => e
      raise GRPC::Internal.new("태그 삭제 실패: #{e.message}")
    end
    private
    # ActiveRecord::Tag 모델을 Grpc::Tag::TagResponse 메시지로 변환
    def build_tag_response(tag)
      created_at_ts = Google::Protobuf::Timestamp.new
      created_at_ts.from_time(tag.created_at) if tag.created_at

      Bannote::Scheduleservice::Tag::V1::Tag.new(
        tag_id: tag.id.to_i,
        name: tag.name.to_s,
        created_by: tag.created_by.to_i,
        created_at: created_at_ts
      )
    end
  end
end
