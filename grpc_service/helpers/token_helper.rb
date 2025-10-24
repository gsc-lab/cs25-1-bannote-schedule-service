require 'grpc'
require 'token/token_pb'
require 'token/token_services_pb'

module TokenHelper
  TOKEN_SERVICE_ADDRESS = "localhost:50051" # 실제 배포시 env 변경 가능

  def self.verify_token(call)
    # 1. metadata에서 토큰 추출
    auth_header = call.metadata["authorization"]
    raise GRPC::Unauthenticated.new("JWT 토큰이 필요합니다") if auth_header.nil?

    token = auth_header.split("Bearer").last&.strip
    raise GRPC::Unauthenticated.new("JWT 토큰이 필요합니다") if token.blank?

    # 2. gRPC stub 생성
    token_stub = Bannote::Tokenservice::Token::V1::TokenService::Stub.new(
      TOKEN_SERVICE_ADDRESS,
      :this_channel_is_insecure
    )

    # 3. TokenService 검증 요청
    req = Bannote::Tokenservice::Token::V1::ValidateAccessTokenRequest.new(access_token: token)
    res = token_stub.validate_access_token(req)

    # 4. 결과 검증
    unless res.valid
      raise GRPC::Unauthenticated.new("유효하지 않은 JWT 토큰입니다")
    end

    # 5. user_id, role 반환
    user_id = res.user_id
    role = res.roles
    [user_id,role]
  rescue GRPC::BadStatus => e
    raise GRPC::Unauthenticated.new("TokenService 검증 실패: #{e.message}")
  rescue => e
    raise GRPC::Internal.new("JWT 인증 중 오류 발생: #{e.message}")
  end
end
