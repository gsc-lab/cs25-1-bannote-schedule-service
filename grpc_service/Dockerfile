# 1. 베이스 이미지 설정
FROM ruby:3.2.9-slim

# 2. 환경 변수 설정
# RAILS_ENV: Rails 환경을 'production'으로 설정합니다.
# LANG: 컨테이너의 기본 언어 및 인코딩을 UTF-8으로 설정합니다.
# APP_HOME: 애플리케이션 코드가 위치할 디렉토리를 지정합니다.
ENV RAILS_ENV=production \
    LANG=C.UTF-8 \
    APP_HOME=/app

# 3. 작업 디렉토리 설정
WORKDIR $APP_HOME

# 4. 시스템 패키지 설치
# - build-essential: Ruby gem 중 C 확장을 컴파일하는 데 필요한 도구를 포함합니다.
# - libmysqlclient-dev: MySQL 데이터베이스 어댑터(mysql2 gem)를 빌드하는 데 필요합니다.
# - curl: 외부 리소스를 다운로드하는 데 사용될 수 있습니다.
# 패키지 목록을 업데이트하고, 필요한 패키지를 설치한 후, apt 캐시를 정리하여 이미지 크기를 줄입니다.
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libmysqlclient-dev \
    curl && \
    rm -rf /var/lib/apt/lists/*

# 5. Bundler 설치 및 설정
# Gemfile.lock에 명시된 특정 버전의 Bundler를 설치합니다.
# --jobs: 병렬로 gem을 설치하여 속도를 높입니다.
# --retry: 네트워크 문제 발생 시 재시도 횟수를 설정합니다.
# --without: development 및 test 그룹의 gem은 설치에서 제외하여 프로덕션 이미지 크기를 최적화합니다.
COPY Gemfile Gemfile.lock ./
RUN bundle install -j "$(nproc)" --retry 3 --without development test

# 6. 애플리케이션 코드 복사
# 빌드 컨텍스트의 모든 파일을 컨테이너의 작업 디렉토리로 복사합니다.
# 이 Dockerfile은 프로젝트 루트에서 `docker build -f grpc_service/Dockerfile .` 명령으로 빌드해야 합니다.
COPY . .

# 7. gRPC 서버 포트 노출
# gRPC 서버가 수신 대기할 포트를 50051로 지정합니다.
EXPOSE 50051

# 8. 컨테이너 실행 명령어
# 컨테이너가 시작될 때 gRPC 서버를 실행합니다.
CMD ["ruby", "grpc_service/server.rb"]
