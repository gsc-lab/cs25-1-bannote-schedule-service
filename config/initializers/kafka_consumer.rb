# Rails.application.config.after_initialize do
#   Thread.new do
#     Rails.logger.info "[Kafka] UserEventConsumer 스레드 시작..."

#     begin
#       UserEventConsumer.new.start
#     rescue => e
#       Rails.logger.error "[Kafka] Consumer 실행 중 에러 발생: #{e.message}"
#       Rails.logger.error e.backtrace.join("\n")
#     end
#   end
# end
# config/initializers/kafka_consumer.rb

# unless ENV["DISABLE_CONSUMER"] == "true"
#   Rails.application.config.after_initialize do
#     Thread.new do
#       Rails.logger.info "[Kafka] UserEventConsumer 스레드 시작..."
# 
#       begin
#         UserEventConsumer.new.start
#       rescue => e
#         Rails.logger.error "[Kafka] Consumer 실행 중 에러 발생: #{e.message}"
#         Rails.logger.error e.backtrace.join("\n")
#       end
#     end
#   end
# end
