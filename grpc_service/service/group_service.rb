require_relative '../../config/environment'
require 'grpc'
require 'group/group_pb'
require 'group/group_service_services_pb'
require 'tag/tag_pb'
require 'securerandom'
require_relative '../helpers/Role_helper'

# 코드를 정리하기 위한 네임스페이스
module Bannote
  module Scheduleservice
    module Group
      module V1
        #  새로운 package 이름에 맞는 클래스 상속
        class GroupServiceHandler < Bannote::Scheduleservice::Group::V1::GroupService::Service
            # 1. 그룹 생성
            def create_group(request, call)
                # 1. 요청 파싱 시작
                group_type_id = request.group_type_id
                group_name = request.group_name
                group_description = request.group_description
                is_public = request.is_public
                is_published = request.is_published
                color_default = request.color_default  ||= "#172C66"
                color_highlight = request.color_highlight ||= "#F4E58F"
                tag_ids =  request.tag_ids

                # 2. 유효성 검사
                # 2.1 필수값  검증
                raise GRPC::InvalidArgument.new("group_name은 필수입니다") if group_name.blank?
                raise GRPC::InvalidArgument.new("group_name은 50자 미만으로 해주세요") if group_name.length > 50
                raise GRPC::InvalidArgument.new("group_type_id는 필수입니다") if group_type_id.nil?
                # 그룹이름
                if ::Group.exists?(group_name: group_name)
                  raise GRPC::AlreadyExists.new("이미 존재하는 그룹이름입니다")
                end

                if is_published && !is_public # 그룹 검색할떄 false이면 공개 x
                  puts "비공개 그룹이 발행되었습니다. 공개목록에는 표시되지않습니다"
                end

                # group_permission 존재 확인 (예약 우선순위 연결)
                permission = ::GroupPermission.find_by(id: group_type_id)
                raise GRPC::InvalidArgument.new("유효하지 않은 예약 우선순위입니다.") if permission.nil?

                # 3. 인증
                user_id, role = RoleHelper.verify_user(call)

                  # 4.그룹 생성
                  group = ::Group.create!(
                    group_type_id: group_type_id,
                    group_name: request.group_name,
                    group_description: request.group_description,
                    is_public: request.is_public,
                    is_published: request.is_published,
                    color_default: request.color_default,
                    color_highlight: request.color_highlight,
                    group_code: SecureRandom.hex(8),
                    created_by: user_id
                  )
                  puts "그룹 생성 Group #{group.id}"

                  # 생성자를 해당 그룹의 맴버로 자동 등록
                  # ::UserGroup.create!(user_id: user_id, group_id: group.id) 나중에 이거를 주석 해제해야함
                  ::UserGroup.create!(user_id: user_id, group_id: group.id, created_at: Time.current) # 이거 나중에 삭제해야함

                  puts "UserGroup created for user_id-#{user_id}, group_id=#{group.id}"

                  # 5. 태그 연결(하나의 테이블은 여러개의 태그를 가질수있기때문에)
                  if request.tag_ids && !request.tag_ids.empty?
                    tag_ids = request.tag_ids.to_a.map!(&:to_i)
                    puts " Processing tag_ids: #{request.tag_ids.join(', ')}"
                    puts "DEBUG: request.tag_ids: #{request.tag_ids.inspect}, type: #{request.tag_ids.class}"
                    existing_tags = ::Tag.where(id: tag_ids)
                    puts "DEBUG: existing_tags: #{existing_tags.inspect}, length: #{existing_tags.length}"
                    if existing_tags.length != request.tag_ids.length
                      missing_tag_ids = request.tag_ids - existing_tags.pluck(:id)
                      raise GRPC::NotFound.new("다음 태그를 찾을 수 없습니다: #{missing_tag_ids.join(', ')}")
                    end
                  # 태그 연결
                  if tag_ids.present?
                    existing_tags = ::Tag.where(id: tag_ids)
                    if existing_tags.size != tag_ids.size
                      missing = tag_ids - existing_tags.pluck(:id)
                      raise GRPC::NotFound.new("다음 태그를 찾을 수 없습니다: #{missing.join(', ')}")
                    end

                    tag_ids.each do |tag_id|
                        # ::GroupTag.create!(group_id: group.id, tag_id: tag_id) 나중에 주석 삭제
                        ::GroupTag.create!(
                          group_id: group.id,
                          tag_id: tag_id,
                        )
                      end
                  end

                # 6.응답생성
                Bannote::Scheduleservice::Group::V1::CreateGroupResponse.new(group: build_group_response(group.reload))
                  end
                rescue GRPC::BadStatus => e
                  raise e  # 원래의 gRPC 에러 그대로 전달
                rescue ActiveRecord::RecordInvalid => e
                  raise GRPC::InvalidArgument.new("그룹 생성 중 오류: #{e.message}")
                rescue => e
                  raise GRPC::Internal.new("그룹 생성 실패: #{e.message}")
                end
                
            # 2. 그룹 목록 조회 (여러 그룹을 한번에 가져옴)
            def get_group_list(request, call)
              user_id, role = RoleHelper.verify_user(call)

              # 1. 기본 그룹 목록
              groups_query = ::Group.all

              # 2. 기본 필터
              group_type_id = request.group_type_id if request.has_group_type_id?
              is_public     = request.is_public     if request.has_is_public?
              is_published  = request.is_published  if request.has_is_published?

              tag_ids   = request.tag_ids.to_a.map(&:to_i).reject(&:zero?)
              tag_names = request.tag_names.to_a.reject(&:blank?)

              groups_query = groups_query.where(group_type_id: group_type_id) if group_type_id
              groups_query = groups_query.where(is_public: is_public) if request.has_is_public?
              groups_query = groups_query.where(is_published: is_published) if request.has_is_published?

              if tag_names.any?
                or_conditions = tag_names.map { |n| "name LIKE ?" }.join(" OR ")
                or_values = tag_names.map { |n| "%#{n}%" }

                # 중요: ::Tag 로 변경해야 autoload 충돌 없음
                tag_ids_from_name = ::Tag.where(or_conditions, *or_values).pluck(:id)

                tag_ids = (tag_ids + tag_ids_from_name).uniq
              end

              if tag_ids.any?
                groups_query =
                  groups_query
                    .joins(:group_tags)
                    .where(group_tags: { tag_id: tag_ids })
                    .group("groups.id")
                    .having("COUNT(DISTINCT group_tags.tag_id) = ?", tag_ids.length)
              end

              groups = groups_query.distinct

              # 페이징
              page     = request.page > 0 ? request.page : 1
              per_page = request.per_page > 0 ? request.per_page : 10

              total_count = groups.count
              total_pages = (total_count / per_page.to_f).ceil
              paginated_groups = groups.limit(per_page).offset((page - 1) * per_page)

              # 북마크 여부
              bookmarked_group_ids = ::UserGroup.where(user_id: user_id).pluck(:group_id).to_set

              grpc_groups = paginated_groups.map do |g|
                grpc_group = build_group_response(g)
                grpc_group.bookmark = bookmarked_group_ids.include?(g.id)
                grpc_group
              end

              Bannote::Scheduleservice::Group::V1::GetGroupListResponse.new(
                group_list_response: Bannote::Scheduleservice::Group::V1::GroupListResponse.new(
                  groups: grpc_groups,
                  page: page,
                  per_page: per_page,
                  total_count: total_count,
                  total_pages: total_pages
                )
              )
            end

          # 3. 그룹 상세 조회(특정 그룹 하나의 상세정보조회)
          def get_group(request, call)
            # 1. 요청 파싱
            group_id = request.group_id

            #  메타데이터
            user_id, role = RoleHelper.verify_user(call)

            group = ::Group.includes(:tags, :group_permission).find(group_id)

            # 응답 변환
            Bannote::Scheduleservice::Group::V1::GetGroupResponse.new(group: build_group_response(group))

              # 5.예외처리
            rescue ActiveRecord::RecordNotFound
              raise GRPC::NotFound.new("그룹을 찾을 수 없습니다.")
            rescue => e
              raise GRPC::Internal.new("그룹 상세 조회 실패:#{e.message}")
          end

          # 4. 그룹 수정
          def update_group(request, call)
            # 1.파싱
            group_id = request.group_id
            raise GRPC::InvalidArgument.new("group_id는 필수 입니다") if group_id.nil? || group_id <= 0

            # 2. 메타데이터
            user_id, role = RoleHelper.verify_user(call)

            # 3.그룹 조회
            group = ::Group.find_by(id: group_id)
            raise GRPC::NotFound.new("삭제할 그룹을 찾을 수 없습니다") unless group

            # 4. 권한 검증
            permission_label = group.group_permission&.permission
            case permission_label
            when "1", "2"
              # 긴급·정규 그룹 → 조교 이상만 수정 가능
              unless RoleHelper.has_authority?(role, 4)
                raise GRPC::PermissionDenied.new("긴급/정규 그룹은 조교 이상만 수정할 수 있습니다.")
              end
            when "3"
              # 개인 그룹 → 구성원만 수정 가능
              member_ids = group.user_groups.pluck(:user_id)
              unless member_ids.include?(user_id)
                raise GRPC::PermissionDenied.new("이 그룹의 구성원이 아닙니다.")
              end
            else
              raise GRPC::InvalidArgument.new("유효하지 않은 권한 값입니다.")
            end

            # 5. 수정 필드
            update_attrs = {}
            # optional은 그 필드 자체를 보낼지 말지 선택할 수 있다
            update_attrs[:group_name] = request.group_name if request.has_group_name?
            update_attrs[:group_description] = request.group_description if request.has_group_description?
            update_attrs[:is_public] = request.is_public if request.has_is_public?
            update_attrs[:is_published] = request.is_published if request.has_is_published?
            update_attrs[:color_default] = request.color_default if request.has_color_default?
            update_attrs[:color_highlight] = request.color_highlight if request.has_color_highlight?

            group.update!(update_attrs)

            # 6. 태그 수정 (전체 갱신 방식)
            if request.tag_ids && !request.tag_ids.empty?
               tag_ids = request.tag_ids.map(&:to_i)
               existing_tags = ::Tag.where(id: tag_ids)
               db_tag_ids = existing_tags.pluck(:id).map(&:to_i)
               missing = tag_ids - db_tag_ids

              if missing.any?
                raise GRPC::NotFound.new("다음 태그를 찾을 수 없습니다: #{missing.join(', ')}")
              end

              group.tags = existing_tags
            end

            # 7. 응답 반환
            Bannote::Scheduleservice::Group::V1::UpdateGroupResponse.new(
              group: build_group_response(group.reload)
            )

            # 8. 예외 처리
            rescue ActiveRecord::RecordNotFound
              raise GRPC::NotFound.new("그룹을 찾을 수 없습니다.")
            rescue ActiveRecord::RecordInvalid => e
              raise GRPC::InvalidArgument.new("입력값이 유효하지 않습니다: #{e.message}")
            rescue => e
              raise GRPC::Internal.new("그룹 수정 실패: #{e.message}")
          end

          # 5. 그룹 삭제
          def delete_group(request, call)
            # 1. 파싱
            group_id = request.group_id

            # 2.유효성 검사
            raise GRPC::InvalidArgument.new("group_id는 필수입니다") if group_id.nil? || group_id <= 0

            # 3. 인증
            user_id, role = RoleHelper.verify_user(call)

            # 4.그룹 조회
            group = ::Group.find_by(id: group_id)
            raise GRPC::NotFound.new("삭제할 그룹을 찾을 수 없습니다") unless group

            # 5.권한 검증 생성자만 삭제 가능
            unless group.created_by == user_id
              raise GRPC::PermissionDenied.new("이 그룹의 생성자만 삭제 할 수 있습니다")
            end

            # 6.삭제 수행
            group.destroy!
            puts "그룹 삭제 완료 ID=#{group.id}, by user_id=#{user_id}"

              # 7.응답 반환
              Bannote::Scheduleservice::Group::V1::DeleteGroupResponse.new(success: true)

            # 8. 예외처리
            rescue ActiveRecord::RecordNotFound
              raise GRPC::NotFound.new("그룹을 찾을 수 없습니다.")
            rescue ActiveRecord::RecordNotDestroyed => e
              raise GRPC::Internal.new("그룹 삭제 실패: #{e.message}")
            rescue GRPC::BadStatus => e
              raise e
            rescue => e
              raise GRPC::Internal.new("그룹 삭제 실패: #{e.message}")
          end

          private # 외부에서 직접 호출 못함
          # ActiveRecord 모델 객체를 gRPC 응답 메시지로 변환하는 헬퍼 메소드
          # grpc가 이해할수있는 응답형태롤 만들어주기 위해서  데이터 변환

          def build_group_response(group) # 결과를 변환해서 gprc에 맞게 보내줌
            tags = group.tags.map do |t|
              Bannote::Scheduleservice::Tag::V1::Tag.new(
                tag_id: t.id,
                name: t.name,
                created_at: Google::Protobuf::Timestamp.new(seconds: t.created_at.to_i)
              )
            end

            Bannote::Scheduleservice::Group::V1::Group.new(
              group_id: group.id.to_i,
              group_code: group.group_code.to_s,
              group_type_id: group.group_type_id.to_i,
              group_name: group.group_name.to_s,
              group_description: group.group_description.to_s,
              is_public: !!group.is_public,
              is_published: !!group.is_published,
              color_default: group.color_default.to_s,
              color_highlight: group.color_highlight.to_s,
              created_at: group.created_at ? Google::Protobuf::Timestamp.new(seconds: group.created_at.to_i) : nil,
              updated_at: group.updated_at ? Google::Protobuf::Timestamp.new(seconds: group.updated_at.to_i) : nil,
              deleted_at: group.deleted_at ? Google::Protobuf::Timestamp.new(seconds: group.deleted_at.to_i) : nil,
              created_by: group.created_by.to_i,
              updated_by: group.updated_by.to_i,
              deleted_by: group.deleted_by.to_i,
              tags: tags,
              bookmark: group.try(:bookmark)
            )
          end
        end
      end
    end
  end
end
