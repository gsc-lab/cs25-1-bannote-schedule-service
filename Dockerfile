# 
# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development.

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.2.9
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libmariadb3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment
ENV RAILS_ENV="development" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems and assets
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libyaml-dev \
    pkg-config \
    default-libmysqlclient-dev \
    default-mysql-client \
    curl \
    dirmngr \
    gnupg \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Node.js & Yarn 설치
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash - && \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarn-archive-keyring.gpg >/dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/yarn-archive-keyring.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y nodejs yarn && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# ENV PATH 수정
ENV PATH="${BUNDLE_PATH}/bin:$PATH"

# Install application gems
COPY Gemfile ./ 
COPY Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy all source
COPY . .

# 권한 부여 + 개행 수정 (CRLF 문제 방지)
RUN chmod +x ./bin/* && \
    sed -i 's/\r$//' ./bin/*

# Bootsnap precompile
RUN bundle exec bootsnap precompile app/ lib/

# 핵심 수정: bundle exec rails 로 자산 빌드
RUN chmod +x ./bin/rails && \
    sed -i 's/\r$//' ./bin/rails && \
    SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

# Final stage for runtime
FROM base

# Copy built artifacts
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# --------------------------------------------------------
# 안전하게 rails 유저/그룹 생성 (충돌 방지 + 디렉토리 보장)
# --------------------------------------------------------
RUN if ! getent group rails; then groupadd --system --gid 1000 rails; fi && \
    if ! id rails >/dev/null 2>&1; then useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash rails; fi && \
    mkdir -p /rails/log /rails/tmp /usr/local/bundle && \
    chown -R rails:rails /rails/log /rails/tmp /usr/local/bundle

USER rails

# Entrypoint & command
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 55005
CMD ["bundle", "exec", "ruby", "grpc_service/server.rb"]
