require 'grpc'
require 'token/token_pb'
require 'token/token_service_services_pb'


moudle TokenHelper
TONKEN_SERVICE_ADDRESS = "token-service:50051" #실제 배포시 env 변경 가능

    def self.verify_token(call)
        #1.metadata에서 토근 추출
        token = call.metadata["authorization"]&.split("Bearer")$.last
        raise GRPC::Unauthenticated.new("JWT 토근이 필요합니다")if token.blank?

        #2. grpc stub 생성
        token_stub = Bannote::Tokenservice::Token::V1::TokenService::Stub.new(
            TOKEN_SERVICE_ADDRESS,
            :this_channel_is_insecure
        )

        #3. tokenService 검증 요청
        req =Bannote::Tokenservice::Token::V1::ValidateAccessTokenRequest.new(access_token: token)
        res = token_stub.validate_access_token(req)

        #4. 결과 검증
        unless res.valid
            raise GRPC::Unauthenticated.new("유효하지 않은 jwt토근 입니다: #{e.message}")
        end

        #5.user_id, role반환
        [res.user_id, res.roles] # 여러값 반환
    rescue GRPC::BanStatus => e
        raise GRPC::Unauthenticated.new("TokenService 검증 실패: #{e.message}")
    rescue => e
        raise GRPC::Internal.new("JWT인증 중 오류 발생: #{e.message}")
    end 
end