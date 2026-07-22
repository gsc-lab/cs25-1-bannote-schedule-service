# frozen_string_literal: true

KarafkaApp.routes.draw do
  topic :user_event do        # 실제 Kafka topic 이름
    consumer UserEventConsumer
  end

  # 필요하면 추가 가능
  # topic :example do
  #   consumer ExampleConsumer
  # end
end
