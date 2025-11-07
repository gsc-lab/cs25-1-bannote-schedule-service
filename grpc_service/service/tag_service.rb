require 'grpc'
require 'tag/tag_pb'
require 'tag/tag_service_services_pb'
require 'common_pb'
require_relative '../helpers/Role_helper'


module Bannote::Scheduleservice::Tag::V1
  class TagServiceHandler < Bannote::Scheduleservice::Tag::V1::TagService::Service

    # 1. 태그 생성
    def create_tag(request, call)

      #1.파싱 
      name = request.name&.strip
      #2. 유효성 검사
      raise GRPC::InvalidArgument.new("태그 이름은 필수입니다")if name.nil? || name.empty?
      user_id, role = RoleHelper.verify_user(call)

      # 관리자 이상만 생성 가능
      unless RoleHelper.has_authority?(user_id, 4)
        raise GRPC::PermissionDenied.new("태그 생성은 조교님 이상 가능합니다.")
      end

      #5.생성
      tag = ::Tag.create!( name: request.name ,created_by: user_id)
      #6. 응답 반환
      Bannote::Scheduleservice::Tag::V1::CreateTagResponse.new(tag: build_tag_response(tag))
    rescue => e
      raise GRPC::Internal.new("태그 생성 실패: #{e.message}")
    end

    # 2. 단일 태그 조회(관리자용)
    def get_tag(request, call)
      user_id, role = RoleHelper.verify_user(call)

    #2. 파싱
      tag_id = request.tag_id
      raise GRPC::InvalidArgument.new("tag_id는 필수 입니다") if tag_id.nil?|| tag_id <=0
    #3. 유효성 검사
      unless RoleHelper.has_authority?(user_id, 4)
        raise GRPC:: PermissionDenied.new("조교이상만 권한 있습니다")
      end
    #4. db조회
      tag = ::Tag.find(request.tag_id)
    #5. 응답 
      Bannote::Scheduleservice::Tag::V1::GetTagResponse.new(tag: build_tag_response(tag))
    #6. 에러
    rescue ActiveRecord::RecordNotFound
      raise GRPC::NotFound.new("태그를 찾을 수 없습니다.")
    rescue => e
        raise GRPC::Internal.new("태그 조회 실패: #{e.message}")
    end

    # 3. 태그 목록 조회 
    def get_tag_list(_request, call)
      begin #예외가 발생할 수 있는 코드
        user_id, role = RoleHelper.verify_user(call)

        #관리자 이상일 경우
        if RoleHelper.has_authority?(user_id, 4)
          tags =::Tag.all.order(created_at: :desc)
        else
          #일반 사용자 공개 태그만 
          tags =::Tag.where(is_public: true).order(created_at: :desc)
        end

      rescue GRPC::Unauthenticated
         tags = ::Tag.where(is_public: true).order(created_at: :desc)
      end

      #응답 
      Bannote::Scheduleservice::Tag::V1::GetTagListResponse.new(
      tag_list_response: Bannote::Scheduleservice::Tag::V1::TagListResponse.new(
        tags: tags.map { |t| build_tag_response(t) }
      )
    )
      
    rescue => e
      raise GRPC::Internal.new("태그 목록 조회 실패: #{e.message}")
    end

    # 4. 태그 삭제
    def delete_tag(request, call)
      #1.메타데이터
      user_id, role = RoleHelper.verify_user(call)

      #2. 파싱
      tag_id = request.tag_id
      raise GRPC::InvalidArgument.new("tag_id는 필수입니다")if tag_id.nil? || tag_id <=0

      #3. 권한검사
      unless RoleHelper.has_authority?(user_id,4)
        raise GRPC::PermissionDenied.new("삭제할 태그를 찾을 수 있습니다")
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
      created_at_ts.from_time(tag.created_at)if tag.created_at

      Bannote::Scheduleservice::Tag::V1::Tag.new(
        tag_id: tag.id.to_i,
        name: tag.name.to_s,
        created_by: tag.created_by.to_i,
        created_at: created_at_ts
      )
    end
  end
end