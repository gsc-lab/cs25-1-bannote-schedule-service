# frozen_string_literal: true

require_relative 'lib/healthcheck/healthcheck_pb'
require_relative 'lib/healthcheck/healthcheck_services_pb'

module Grpc
  module Health
    module V1
      class HealthServiceHandler < Grpc::Health::V1::Health::Service
        def check(_request, _call)
          Grpc::Health::V1::HealthCheckResponse.new(status: "SERVING")
        end
      end
    end
  end
end
