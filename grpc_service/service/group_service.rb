#  새로운 파일 위치에 맞는 require 경로
require 'grpc'
require 'group/group_pb'
require 'group/group_service_services_pb'
# TagResponse를 사용하므로 tag 폴더의 pb 파일을 불러옵니다.
require 'tag/tag_pb'
require 'securerandom'
require_relative '../helpers/token_helper'


# 코드를 정리하기 위한 네임스페이스
module Bannote
  module Scheduleservice
    module Group
      module V1
        #  새로운 package 이름에 맞는 클래스 상속
        class GroupServiceHandler < Bannote::Scheduleservice::Group::V1::GroupService::Service
          # 1. 그룹 생성
          def create_group(request, call)
          #1. 요청 파싱 시작 
          group_type_id = request.group_type_id
          group_name = request.group_name
          group_description = request.group_description
          is_public = request.is_public
          is_published = request.is_published
          color_default = request.color_default
          color_highlight = request.color_highlight
          tag_ids =  request.tag_ids

          #2. 유효성 검사
          #2.1 필수값  검증
          raise GRPC::InvalidArgument.new("group_name은 필수입니다")if group_name.blank?
          raise GRPC::InvalidArgument.new("group_type_id는 필수입니다")if group_type_id.nil?
          raise GRPC::InvalidArgument.new("color_default는 hex형식이어야합니다")unless color_default =~ /^#[0-9A-Fa-f]{6}$/
          raise GRPC::InvalidArgument.new("group_name은 50자 미만으로 해주세요")if group_name.length >50
          if is_published && !is_public # 그룹 검색할떄 false이면 공개 x
            puts "비공개 그룹이 발행되었습니다 . 공개목록에는 표시되지않습니다"
          end

          #1.2 기본 색깔 
          color_default  ||= "172C66x4"
          color_highlight ||=  "F4E58F"

       
          #3. 인증(jwt)
          #1.  jwt인증
          # user_id,role = TokenHelper.verify_token(call)
          user_id, role = [1, "admin"]  # 임시 테스트용
          puts "인증 성공 user_id=#{user_id},role=#{role}"

          #2. 권한 검증 groud_tpye_id =1 (조교님 이상 생성가능) groud_type_id =2(전부다 가능)
        case request.group_type_id
        when 1  #정규 수업
          unless %W[assistant professor admin].include?(role) #%w을 사용하면 중간에,안넣어도됨
            raise GRPC::PermissionDenied.new("기본 그룹은 조교 이상만 생성 할 수있습니다")
          end
        when 2 #개인 그룹
          puts " 개인 그룹 생성 role #{role}"
        else
          raise GRPC::InvalidArgument.new("유효하지 않는 그룹 타입입니다")
        end
          #4.그룹 생성
            group = ::Group.create!(
              group_type_id: request.group_type_id,
              group_name: request.group_name,
              group_description: request.group_description,
              is_public: request.is_public,
              is_published: request.is_published,
              color_default: request.color_default,
              color_highlight: request.color_highlight,
              group_permission_id: request.group_permission_id,
              group_code: SecureRandom.hex(8),
              created_by: user_id
            )
            puts "Group created with ID: #{group.id}"
            #생성자를 해당 그룹의 맴버로 자동 등록
            ::UserGroup.create!(user_id: user_id, group_id: group.id)
            puts "UserGroup created for user_id-#{user_id}, group_id=#{group.id}"


            # 5. 태그 연결(하나의 테이블은 여러개의 태그를 가질수있기때문에)
            if request.tag_ids && !request.tag_ids.empty?
              puts " Processing tag_ids: #{request.tag_ids.join(', ')}"
              existing_tags = ::Tag.where(id: request.tag_ids)
              if existing_tags.length != request.tag_ids.length
                missing_tag_ids = request.tag_ids - existing_tags.pluck(:id)
                raise GRPC::NotFound.new("다음 태그를 찾을 수 없습니다: #{missing_tag_ids.join(', ')}")
              end

              request.tag_ids.each do |tag_id|
                ::GroupTag.create!(group_id: group.id, tag_id: tag_id)
              end
            end

           # 6.응답생성
          Bannote::Scheduleservice::Group::V1::CreateGroupResponse.new(group: build_group_response(group.reload))
          rescue ActiveRecord::RecordInvalid => e
            puts " Caught ActiveRecord::RecordInvalid: #{e.message}"
            raise GRPC::InvalidArgument.new("그룹에 태그 추가 실패: #{e.message}")
          rescue => e
            puts "Caught generic exception: #{e.class}: #{e.message}"
            raise GRPC::Internal.new("그룹 생성 실패: #{e.message}")
          end

          # 2. 그룹 목록 조회 (여러 그룹을 한번에 가져옴)
          def get_group_list(request, call)
            #1. 요청 파싱 
            group_type_id = request.group_type_id if request.has_group_type_id? #has 는 option일떄만 붙임 
            is_public =  request.is_public if request.has_is_public? 
            is_published = request.is_published if request.has_is_published?
            tag_ids = request.tag_ids  #repeated는 그대로 사용해도 됨(배열 형태)

            #2.유효성 검사
            if request.has_group_type_id? && ![1,2].include?(request.group_type_id)
              raise GRPC::InvalidArgument.new("유효하지 않은 group_type_id입니다")
            end

            if request.tag_ids.any?
              unless request.tag_ids.all? {|id| id.is_a?(Integer) && id.positive?}
                raise GRPC::InvalidArgument.new("tag_ids는 양의 정수여야 합니다")
              end
            end

            # jwt인증
            user_id,role = TokenHelper.verify_token(call)

            #3.권한 검증 (조회는 전체 공개 비공개는 안뜨게)
            if request.has_is_public? && request.is_public == false
              #비공개 그룹 조회시
              groups =::Group.joins(:user_groups)
                              .where(user_groups: {user_id: user_id})
            else
              #공개 그룹은 전체 조회 가능
              groups = ::Group.where(is_public: true)
            end
            
            # 4. 추가 필터 
            groups = groups.where(group_type_id: group_type_id) if group_type_id
            groups = groups.where(is_published: is_published) if request.has_is_published?

            #5. 응답 생성
            responses = groups.map { |g| build_group_response(g)}
            Bannote::Scheduleservice::Group::V1::GroupListResponse.new(groups: responses)
          rescue => e
            puts " 그룹 목록 조회 실패: #{e.class} - #{e.message}"
            raise GRPC::Internal.new("그룹 목록 조회 실패: #{e.message}")
          end

          # 3. 그룹 상세 조회(특정 그룹 하나의 상세정보조회)
          def get_group(request, call)
            # 1. 요청 파싱
            group_id = request.group_id

            #  jwt인증
            user_id,role = TokenHelper.verify_token(call)

            #2. 유효성 검사
            raise GRPC::InvalidArgument.new("group_id는 필수 입니다") if group_id.nil? || group_id <= 0
            #3. db조회
             group = ::Group.includes(:tags).find(group_id)
            #4. 응답 변환
            Bannote::Scheduleservice::Group::V1::GetGroupResponse.new(group: build_group_response(group))

            #5.예외처리
          rescue ActiveRecord::RecordNotFound
            raise GRPC::NotFound.new("그룹을 찾을 수 없습니다.")
          rescue => e
            raise GRPC::Internal.new("그룹 상세 조회 실패:#{e.message}")
          end

          # 4. 그룹 수정
          def update_group(request, call)
            #1.파싱
            group_id = request.group_id
            raise GRPC::InvalidArgument.new("group_id는 필수 입니다")if group_id.nil? || group_id <=0

            #2. jwt인증
            user_id, role = TokenHelper.verify_token(call)
            
            #3.그룹 조회
            group = ::Group.find_by(id: group_id)
            raise GRPC::NotFound.new("삭제할 그룹을 찾을 수 없습니다").unless group

            #4. 권한 검증
            case group.group_type_id
            when 1 #정규 수업
              unless %w[assistant professor admin].include?(role)
                raise GRPC::PermissionDenied.new("정규 수업 그룹은 조교 이상만 삭제할 수 있습니다")
              end
            when 2
              unless group.create_by == user.id
                  raise GRPC::PermissionDenied.new("개인그룹은 생성자만 삭제할 수 있습니다")
              end
            else
              raise GRPC::InvalidArgument.new("유효하지 않은 group_type_id입니다")
            end
           #5. 수정 필드
            update_attrs = {}
            #optional은 그 필드 자체를 보낼지 말지 선택할 수 있다
            update_attrs[:group_name] = request.group_name if request.has_group_name?
            update_attrs[:group_description] = request.group_description if request.has_group_description?
            update_attrs[:is_public] = request.is_public if request.has_is_public?
            update_attrs[:is_published] = request.is_published if request.has_is_published?
            update_attrs[:color_default] = request.color_default if request.has_color_default?
            update_attrs[:color_highlight] = request.color_highlight if request.has_color_highlight?

            group.update!(update_attrs)

            # 6. 태그 수정 (전체 갱신 방식)
            if request.tag_ids && !request.tag_ids.empty?
              group.tags = ::Tag.where(id: request.tag_ids)
            end

           # 7. 응답 반환
            Bannote::Scheduleservice::Group::V1::UpdateGroupResponse.new(
              group: build_group_response(group.reload)
            )
          
          #8. 예외 처리
          rescue ActiveRecord::RecordNotFound
            raise GRPC::NotFound.new("그룹을 찾을 수 없습니다.")
          rescue ActiveRecord::RecordInvalid => e
            raise GRPC::InvalidArgument.new("입력값이 유효하지 않습니다: #{e.message}")
          rescue => e
            raise GRPC::Internal.new("그룹 수정 실패: #{e.message}")
          end

          # 5. 그룹 삭제
          def delete_group(request, call)
          #1. 파싱
          group_id = request.group_id
          #2.유효성 검사
          raise GRPC::InvalidArgument.new("group_id는 필수입니다") if group_id.nil? || group_id <= 0
          # 3. JWT 인증
          user_id, role =TokenHelper.verify_token(call)

          #4.그룹 조회
          group = ::Group.find_by(id: group_id)
          raise GRPC::NotFound.new("삭제할 그룹을 찾을 수 없습니다") unless group

          #5.권한 검증
          case group.group_type_id
            when 1 #정규수업
              unless %w[assistant professor admin].include?(role)
                raise GRPC::PermissionDenied.new("정규 수업 그룹은 조교 이상만 삭제 할 수있습니다")
              end
            when 2 # 개인그룹
              unless group.created_by == user_id
                raise GRPC::PermissionDenied.new("개인 그룹은 생성자만 삭제할 수 있습니다.")
              end
            else
              raise GRPC::InvalidArgument.new("유효하지 않은 group_type_id입니다.")
            end

       
            #6.삭제 수행
            group.destroy!
            puts "그룹 삭제 완료 ID=#{group.id}, by user_id=#{user_id}"

            #7.응답 반환
              Bannote::Scheduleservice::Group::V1::DeleteGroupResponse.new(success: true)
            
            #8. 예외처리
            rescue ActiveRecord::RecordNotFound
              raise GRPC::NotFound.new("그룹을 찾을 수 없습니다.")
            rescue ActiveRecord::RecordNotDestroyed => e
              raise GRPC::Internal.new("그룹 삭제 실패: #{e.message}")
            rescue GRPC::BadStatus => e
              raise e
            rescue => e
              raise GRPC::Internal.new("그룹 삭제 실패: #{e.message}")
            end

          private #외부에서 직접 호출 못함
          # ActiveRecord 모델 객체를 gRPC 응답 메시지로 변환하는 헬퍼 메소드
          #grpc가 이해할수있는 응답형태롤 만들어주기 위해서  데이터 변환

          def build_group_response(group) #결과를 변환해서 gprc에 맞게 보내줌
            tags = group.tags.map do |t|
              Bannote::Scheduleservice::Tag::V1::Tag.new(
                tag_id: t.id,
                name: t.name,
                created_at: Google::Protobuf::Timestamp.new(seconds: t.created_at.to_i)
              )
            end

            Bannote::Scheduleservice::Group::V1::Group.new(
              group_id: group.id,
              code: group.group_code,
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
