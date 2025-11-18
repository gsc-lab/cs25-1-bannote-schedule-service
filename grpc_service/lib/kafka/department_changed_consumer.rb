require_relative "consumer"
require "events/v1/user_events_pb"
class DepartmentChangedConsumer
#토픽이름 
  TOPIC = "department.changed"
 # Consumer 시작
  def self.start
    retries = 0
    max_retries = 5
    retry_delay = 5 # seconds

    begin
      kafka = KafkaConsumer.client
      # topic의 모든 메시지를 수신 
      kafka.each_message(topic: TOPIC, start_from_beginning: false) do |message|
        begin
          # 수신된 protobuf 바이너리 메시지를 decode하여 Ruby 객체로 변환
          event = Bannote::Commonservice::Events::V1::DepartmentChangedEvent.decode(message.value)
          # 변환된 event 객체를 실제 처리 로직에 전달
          handle_event(event)
        rescue Google::Protobuf::ParseError => e
          puts "[DepartmentChangedConsumer] Could not parse message: #{message.value.inspect}"
          puts "[DepartmentChangedConsumer] ParseError: #{e.message}"
        end
      end
    rescue Kafka::LeaderNotAvailable => e
      if retries < max_retries
        retries += 1
        puts "[DepartmentChangedConsumer] Leader not available. Retrying in #{retry_delay} seconds... (Attempt #{retries}/#{max_retries})"
        sleep retry_delay
        retry
      else
        puts "[DepartmentChangedConsumer] Max retries reached. Could not connect to Kafka."
        raise e
      end
    end
  end
  # 이벤트 처리 로직: DB 반영
  def self.handle_event(event)
    begin
    # event 객체에서 필드 추출 
      department_code = event.department_code
      department_name = event.department_name

      puts "[DepartmentChangedConsumer] received: #{department_code}"
     # DB에서 department_code로 학과 조회, 없으면 새로 생성
      dept = ::Department.find_or_initialize_by(department_code: department_code)
    # 최신 학과명 업데이트
      dept.department_name = department_name
    # DB 저장
      dept.save!

    rescue => e
    # 에러 발생 시 로그 출력
      puts "[DepartmentChangedConsumer] Error: #{e.message}"
    end
  end
end

