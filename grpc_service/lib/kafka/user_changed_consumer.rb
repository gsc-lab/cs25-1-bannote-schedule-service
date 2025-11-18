# Kafka Consumer: UserChangedEvent 처리
require 'events/v1/user_events_pb'

class UserChangedConsumer
  # Kafka에서 구독할 토픽 이름 (producer의 publish topic과 동일해야 함)
  TOPIC = "user.changed"

  # Consumer 시작: Kafka 메시지를 무한 스트림으로 계속 읽는다
  def self.start
    retries = 0
    max_retries = 5
    retry_delay = 5 # seconds

    begin
      kafka = KafkaConsumer.client  # Kafka 클라이언트 생성 (Singleton)

      # 지정한 topic의 메시지를 실시간으로 읽음 (start_from_beginning=false → 새로운 메시지부터)
      kafka.each_message(topic: TOPIC, start_from_beginning: false) do |message|
        begin
          # Protobuf 직렬화된 메시지를 역직렬화하여 Ruby 객체로 변환
          event = Bannote::Commonservice::Events::V1::UserChangedEvent.decode(message.value)
          # 변환된 event 객체를 처리
          handle_event(event)
        rescue Google::Protobuf::ParseError => e
          puts "[UserChangedConsumer] Could not parse message: #{message.value.inspect}"
          puts "[UserChangedConsumer] ParseError: #{e.message}"
        end
      end
    rescue Kafka::LeaderNotAvailable => e
      if retries < max_retries
        retries += 1
        puts "[UserChangedConsumer] Leader not available. Retrying in #{retry_delay} seconds... (Attempt #{retries}/#{max_retries})"
        sleep retry_delay
        retry
      else
        puts "[UserChangedConsumer] Max retries reached. Could not connect to Kafka."
        raise e
      end
    end
  end

  # Kafka 이벤트 처리 → DB 업데이트 수행
  def self.handle_event(event)
    begin
      puts "UserChangedEvent 수신: #{event.user_code}"

      # user_number 기준으로 유저 조회, 없으면 새로 생성
      user = User.find_or_initialize_by(user_number: event.user_code)

      # Proto 이벤트에서 들어온 최신 정보로 업데이트
      user.name       = event.user_name
      user.email      = event.user_email
      user.department = event.department_code

      # DB 저장
      user.save!

    rescue => e
      # Consumer는 절대 죽으면 안 되기 때문에 무조건 rescue 처리
      puts "[UserChangedConsumer] Error: #{e.message}"
    end
  end
end
