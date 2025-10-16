require 'grpc'
require_relative './reservation_services_pb'

def main
  stub = Reservation::ReservationService::Stub.new('localhost:50051', :this_channel_is_insecure)

  req = Reservation::ReservationRequest.new(
    name: "홍길동",
    people: 3,
    time: "2025-09-16 18:00"
  )

  resp = stub.create_reservation(req)
  puts "응답: #{resp.message}"
end

main
