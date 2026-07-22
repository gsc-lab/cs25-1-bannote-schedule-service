require 'grpc'

# gRPC 코드 경로 추가
$LOAD_PATH.unshift(File.expand_path('./lib', __dir__))
require 'token/token_pb'
require 'token/token_services_pb'


module Bannote
    module Tokenservice
        module Token
            module V1
                class TokenServiceHandler < Bannote::Tokenservice::Token::V1::TokenService::Service
                    # 엑세스 토큰 발급
                    def generate_access_token(request, call)
                        puts "GenerateAccessToken 요청 받음 (user_id=#{request.user_id}, roles=#{request.roles})"

                        # 단순히 토큰문자열을 만들어 리턴
                        Bannote::Tokenservice::Token::V1::GenerateAccessTokenResponse.new(
                            access_token: "test_token_#{request.user_id}_#{request.roles}",
                            expires_at: (Time.now + 3600).to_i
                        )
                    end

                    # 토큰검증
                    def validate_access_token(request, call)
                        puts "ValidateAccessToken 요청 받음 token=#{request.access_token}"

                        token = request.access_token

                        valid = token.start_with?("test_token_")

                        if valid
                            parts = token.split("_")
                            user_id = parts[2] || "1"
                            roles = parts[3] || "admin"

                             Bannote::Tokenservice::Token::V1::ValidateAccessTokenResponse.new(
                                valid: true,
                                user_id: user_id,
                                roles: roles,
                                error: ""
                            )
                        else
                            Bannote::Tokenservice::Token::V1::ValidateAccessTokenResponse.new(
                                valid: false,
                                user_id: "",
                                roles: "",
                                error: "invalid token"
                            )
                        end
                    end
                end
            end
        end
    end
end


# 서버 실행부

server = GRPC::RpcServer.new
server.add_http2_port('0.0.0.0:50051', :this_port_is_insecure)
server.handle(Bannote::Tokenservice::Token::V1::TokenServiceHandler)
puts "TokenService gRPC 서버 실행 중... (port 50051)"
server.run_till_terminated
