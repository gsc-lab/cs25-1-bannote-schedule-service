# frozen_string_literal: true

class KarafkaApp < Karafka::App
  setup do |config|
    # docker-compose 환경변수 KAFKA_BROKERS 그대로 사용
    config.kafka = {
      'bootstrap.servers': ENV.fetch('KAFKA_BROKERS', 'schedule-service-kafka:9092')
    }

    config.client_id = 'ban_note_app'
  end
end
