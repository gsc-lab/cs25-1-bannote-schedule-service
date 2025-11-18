require "kafka"

module KafkaConsumer
  def self.client
    Kafka.new(["kafka:9092"], client_id: "schedule-service")
  end
end
