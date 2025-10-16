require 'grpc'
require 'tag/tag_pb'
require 'tag/tag_service_services_pb'
# GetTagList에서 Empty 메시지를 사용하므로 common_pb를 불러옵니다.
require 'common_pb'


module Bannote::Scheduleservice::Tag::V1
  class TagServiceHandler < Bannote::Scheduleservice::Tag::V1::TagService::Service

    # 1. 태그 생성
    def create_tag(request, _call)
      tag = Tag.create!(
        name: request.name,
        created_by: 1 # TODO: 나중에 인증된 사용자 ID로 변경
      )
      build_tag_response(tag)
    rescue => e
      raise GRPC::Internal.new("태그 생성 실패: #{e.message}")
    end

    # 2. 단일 태그 조회
    def get_tag(request, _call)
      tag = Tag.find(request.tag_id)
      build_tag_response(tag)
    rescue ActiveRecord::RecordNotFound
      raise GRPC::NotFound.new("태그를 찾을 수 없습니다.")
    end

    # 3. 태그 목록 조회
    def get_tag_list(_request, _call)
      tags = Tag.order(created_at: :desc).map do |t|
        build_tag_response(t)
      end
      Grpc::Tag::TagListResponse.new(tags: tags)
    end

    # 4. 태그 삭제
    def delete_tag(request, _call)
      tag = Tag.find_by(id: request.tag_id)
      if tag
        tag.destroy
        Grpc::Tag::DeleteTagResponse.new(success: true)
      else
        raise GRPC::NotFound.new("삭제할 태그를 찾을 수 없습니다.")
      end
    rescue => e
      raise GRPC::Internal.new("태그 삭제 실패: #{e.message}")
    end

    private

    # ActiveRecord::Tag 모델을 Grpc::Tag::TagResponse 메시지로 변환
    def build_tag_response(tag)
      Grpc::Tag::TagResponse.new(
        tag_id: tag.id,
        name: tag.name,
        created_by: tag.created_by,
        created_at: Google::Protobuf::Timestamp.new(seconds: tag.created_at.to_i)
      )
    end
  end
end