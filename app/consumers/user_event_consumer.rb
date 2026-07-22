# frozen_string_literal: true

require 'proto/common_service/events/enums_pb'
require 'proto/common_service/events/user_events_pb'

class UserEventConsumer < ApplicationConsumer
  def consume
    params_batch.each do |params|
      begin
        event = Bannote::Commonservice::Events::V1::UserChangedEvent.decode(params.raw_payload)
        handle_event(event)
      rescue => e
        puts "[Karafka] decode 실패: #{e.message}"
      end
    end
  end

  private

  def handle_event(event)
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

    puts "[Karafka] user 업데이트 완료: #{user.user_number}"
  end

  def update_department(event)
    return if event.department_code.nil?

    dept = ::Department.find_or_initialize_by(department_code: event.department_code)

    dept.update!(
      department_name: event.department_name
    )

    puts "[Karafka] department 업데이트 완료: #{dept.department_code}"
  end
end
