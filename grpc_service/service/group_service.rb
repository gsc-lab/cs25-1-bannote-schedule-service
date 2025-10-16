#  새로운 파일 위치에 맞는 require 경로
require 'grpc'
require 'group/group_pb'
require 'group/group_service_services_pb'
# TagResponse를 사용하므로 tag 폴더의 pb 파일을 불러옵니다.
require 'tag/tag_pb'

# 코드를 정리하기 위한 네임스페이스
module Bannote
  module Scheduleservice
    module Group
      module V1
        #  새로운 package 이름에 맞는 클래스 상속
        class GroupServiceHandler < Bannote::Scheduleservice::Group::V1::GroupService::Service

          # 1. 그룹 생성
          def create_group(request, _call)
            group = ::Group.create!(
              group_type_id: request.group_type_id,
              group_name: request.group_name,
              group_description: request.group_description,
              is_public: request.is_public,
              is_published: request.is_published,
              color_default: request.color_default,
              color_highlight: request.color_highlight,
              group_permission_id: request.group_permission_id,
              created_by: 1 # 나중에 인증된 사용자 ID로 변경
            )

            # 태그 연결(하나의 테이블은 여러개의 태그를 가질수있기때문에)
            if request.tag_ids
              request.tag_ids.each do |tag_id|
                ::GroupTag.create!(group_id: group.id, tag_id: tag_id)
              end
            end

            build_group_response(group.reload)
          rescue => e
            raise GRPC::Internal.new("그룹 생성 실패: #{e.message}")
          end

          # 2. 그룹 목록 조회 (여러 그룹을 한번에 가져옴)
          def get_group_list(request, _call)
            groups = ::Group.all # 기본적으로 모든 그룹 조회
            
            groups = groups.where(group_type_id: request.group_type_id) if request.group_type_id != 0
            groups = groups.where(is_public: request.is_public) if request.has_is_public?
            groups = groups.where(is_published: request.is_published) if request.has_is_published?

            # 태그 필터링
            if request.tag_ids && !request.tag_ids.empty?
              groups = groups.joins(:tags).where(tags: { id: request.tag_ids }).distinct
            end

            responses = groups.map { |g| build_group_response(g) }
            Bannote::Scheduleservice::Group::V1::GroupListResponse.new(groups: responses)
          end

          # 3. 그룹 상세 조회(특정 그룹 하나의 상세정보조회)
          def get_group(request, _call)
            group = ::Group.find(request.group_id)
            build_group_response(group)
          #에러나니깐 서버에 던짐
          rescue ActiveRecord::RecordNotFound
            raise GRPC::NotFound.new("그룹을 찾을 수 없습니다.")
          end

          # 4. 그룹 수정
          def update_group(request, _call)
            group = ::Group.find(request.group_id)
            
            update_attrs = {}
            #optional은 그 필드 자체를 보낼지 말지 선택할 수 있다
            update_attrs[:group_name] = request.group_name if request.has_group_name?
            update_attrs[:group_description] = request.group_description if request.has_group_description?
            update_attrs[:is_public] = request.is_public if request.has_is_public?
            update_attrs[:is_published] = request.is_published if request.has_is_published?
            update_attrs[:color_default] = request.color_default if request.has_color_default?
            update_attrs[:color_highlight] = request.color_highlight if request.has_color_highlight?

            group.update!(update_attrs)

            # 태그 수정 (전체 갱신 방식)
            if request.tag_ids
              group.tags = ::Tag.where(id: request.tag_ids)
            end

            build_group_response(group.reload)
          rescue ActiveRecord::RecordNotFound
            raise GRPC::NotFound.new("그룹을 찾을 수 없습니다.")
          rescue => e
            raise GRPC::Internal.new("그룹 수정 실패: #{e.message}")
          end

          # 5. 그룹 삭제
          def delete_group(request, _call)
            group = ::Group.find_by(id: request.group_id)
            if group
              group.destroy
              Bannote::Scheduleservice::Group::V1::DeleteGroupResponse.new(success: true)
            else
              raise GRPC::NotFound.new("삭제할 그룹을 찾을 수 없습니다.")
            end
          rescue => e
            raise GRPC::Internal.new("그룹 삭제 실패: #{e.message}")
          end

          private

          # ActiveRecord 모델 객체를 gRPC 응답 메시지로 변환하는 헬퍼 메소드
          #grpc가 이해할수있는 응답형태롤 만들어주기 위해서  데이터 변환
          def build_group_response(group)
            #TagResponse도 새로운 모듈 이름으로 생성
            tags = group.tags.map do |t|
              Bannote::Scheduleservice::Tag::V1::TagResponse.new(
                tag_id: t.id,
                name: t.name,
                created_by: t.created_by || 0,
                created_at: Google::Protobuf::Timestamp.new(seconds: t.created_at.to_i)
              )
            end

            # GroupResponse도 새로운 모듈 이름으로 생성
            Bannote::Scheduleservice::Group::V1::GroupResponse.new(
              group_id: group.id,
              group_type_id: group.group_type_id,
              group_name: group.group_name,
              group_description: group.group_description || "",
              is_public: group.is_public,
              is_published: group.is_published,
              color_default: group.color_default || "",
              color_highlight: group.color_highlight || "",
              created_at: group.created_at ? Google::Protobuf::Timestamp.new(seconds: group.created_at.to_i) : nil,
              updated_at: group.updated_at ? Google::Protobuf::Timestamp.new(seconds: group.updated_at.to_i) : nil,
              deleted_at: group.deleted_at ? Google::Protobuf::Timestamp.new(seconds: group.deleted_at.to_i) : nil,
              created_by: group.created_by || 0,
              updated_by: group.updated_by || 0,
              deleted_by: group.deleted_by || 0,
              tags: tags
            )
          end
        end
      end
    end
  end
end
