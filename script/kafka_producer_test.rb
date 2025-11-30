# script/kafka_producer_test.rb
require File.expand_path('../config/environment', __dir__)
Rails.application.eager_load!

require 'kafka'
require "common-service/events/enums_pb"
require "common-service/events/user_events_pb"
require "google/protobuf/timestamp_pb"

puts "[Kafka] producer start..."

kafka_broker = ENV["KAFKA_BROKER"] || "localhost:9095"
kafka = Kafka.new([kafka_broker], client_id: "schedule-test-producer")

# timestamp 생성 (from_time 쓰지 말고 직접 값 넣기)
now = Time.now
ts = Google::Protobuf::Timestamp.new(
  seconds: now.to_i,
  nanos: now.nsec
)

event = Bannote::Commonservice::Events::V1::UserChangedEvent.new(
  event_id: "test-event-1",
  event_type: Bannote::Commonservice::Events::V1::EventType::EVENT_TYPE_UPDATED,
  timestamp: ts,
  triggered_by: "test-script",

  user_code: "U9999",
  user_email: "test@example.com",
  user_name: "테스트유저",
  family_name: "홍",
  given_name: "길동",
  user_type: Bannote::Commonservice::Events::V1::UserType::USER_TYPE_STUDENT,
  user_status: Bannote::Commonservice::Events::V1::UserStatus::USER_STATUS_ACTIVE,

  department_code: "D001",
  department_name: "AI학과"
)

encoded = Bannote::Commonservice::Events::V1::UserChangedEvent.encode(event)
producer = kafka.producer
producer.produce(encoded, topic: "user.changed")
producer.deliver_messages

puts "[Kafka] test message sent to #{kafka_broker} on topic 'user.changed'!"
