require_relative 'stratum'

user = "brio85963.mojo"
password = "mojo"
host = "api.bitcoin.cz"
port = 8332
serial_port = "COM3"

class TimestampReceivingService < StratumService
  # This catches the notification of the 'example.pubsub.time_event'
  def time_event(params)
    puts "New timestamp received: ";
    puts params.inspect
  end
end

c = StratumClient.new(host, port)

# Expose service for receiving broadcasts about new blocks 
c.register_service('example.pubsub', TimestampReceivingService.new)

# Subscribe for receiving unix timestamps from stratum server
c.add_request('example.pubsub.subscribe', [1])

# Perform some standard RPC calls
#result = c.add_request('example.hello_world', [])
result2 = c.add_request('example.ping', ['ahoj'])
c.communicate

puts result.get.inspect
puts result2.get.inspect

# Another call using the same session, but remote service will throw an exception
result = c.add_request('example.throw_exception', [])
c.communicate

begin
  puts result.get.inspect
rescue
  puts "RPC call failed, which is expected"
end

c.close
