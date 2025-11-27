# app/consumers/user_event_consumer.rb

require 'kafka'
require 'common-service/events/enums_pb'
require 'common-service/events/user_events_pb'

class UserEventConsumer
  def initialize
    @kafka = Kafka.new(
      [ENV["KAFKA_BROKER"] || "kafka:9092"],
      client_id: "schedule-service"
    )

    @consumer = @kafka.consumer(group_id: "schedule-service-group")
    @consumer.subscribe("user.changed")
  end

  def start
    puts "kafka consumer 시작"

    @consumer.each_message do |msg|
      begin
        event = Bannote::Commonservice::Events::V1::UserChangedEvent.decode(msg.value)
        handle_user_changed(event)
      rescue => e
        puts "decode 실패: #{e.message}"
      end
    end
  end

  private

  def handle_user_changed(event)
    puts "schedule-service 유저 변경 처리 완료: #{event.user_code}"
    update_user(event)
    update_department(event)
  end

  def update_user(event)
    user = ::User.find_or_initialize_by(user_number: event.user_code)

    user.update!(
      name: event.user_name,
      email: event.user_email,
      department: event.department_name,
      default_group_id: user.default_group_id || 1
    )

    puts "user 업데이트 완료: #{user.id}"
  end

  def update_department(event)
    return if event.department_code.nil?

    dept = ::Department.find_or_initialize_by(department_code: event.department_code)

    dept.update!(
      department_name: event.department_name
    )

    puts "Department 업데이트 완료: #{dept.department_code}"
  end
end
