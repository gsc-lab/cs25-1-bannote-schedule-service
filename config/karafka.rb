# frozen_string_literal: true

class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka = {
      'bootstrap.servers': ENV.fetch('KAFKA_BROKERS', 'schedule-service-kafka:9092')
    }
    config.client_id = 'ban_note_app'
  end

  routes.draw do
    topic :'user.changed' do    # 실제 topic 이름에 맞추기
      consumer UserEventConsumer
    end
  end
end
