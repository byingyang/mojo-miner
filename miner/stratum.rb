require 'securerandom'
require 'digest/md5'
require 'socket'
require 'json'

class Result

  def initialize(req_id)
    @request_id = req_id
    @finished = false
  end

  def set_result(result, err_code, err_msg)
    raise "Result for the request request ID #{@request_id} is already known" if @finished
    @finished = true
    @result = result
    @err_code = err_code
    @err_msg = err_msg
  end

  def get
    raise "Result for request ID #{@request_id} is not received yet" if @finished
    raise "Code #{@err_code}: Message #{@err_msg}" if !@err_code.nil? || !@err_msg.nil?
    @result
  end
end

class StratumService
end

class StratumClient

  attr_accessor :push_url

  def initialize(host, port, timeout = 20)
    @curr_req_id = 1
    @host = host
    @port = port
    @timeout = timeout
    @push_url = nil
    @sock = nil
    @buffer = []
    @lookup_table = {}
    @services = {}
    connect
  end

  def connect
    @sock = TCPSocket.new(@host, @port)
  end

  def close
    if !@sock.nil?
      @sock.close
      @sock = nil
    end
  end

  def parse_method(method)
    service_type = method.split('.').join('.')
    method.gsub!("#{service_type}.", '')
    return service_type, method
  end

  def register_service(service_type, instance)
    @services[service_type] = instance;
  end

  def process_local_service(method, params)
    service_type, m = parse_method(method)
    raise "Local service '#{service_type}' not found." if !@services.has_key?(service_type)
    return call_user_func([@services[service_type], m], params)
  end

  def add_request(method, args)
    request_id = @curr_req_id
    @curr_req_id += 1
    @buffer << build_request(request_id, method, args)

    result = Result.new(request_id)
    @lookup_table[request_id] = result
    result
  end

  def communicate
    puts @buffer
    @sock.write(@buffer.join(''))
    @buffer = []

    while line = @sock.gets
      begin
        obj = JSON.parse(line.chop)
        if obj.nil?
          # Cannot decode line
          puts "Cannot decode line '#{line}'."
        end
      rescue
        puts "Cannot decode line '#{line}'."
      end

      if !obj.nil?
        if obj.has_key?('method')
          # It's the request or notification

          # TODO: Add exception handling
          resp = process_local_service(obj['method'], obj['params'])

          if(obj.has_key?('id'))
            # It's the RPC request, let's include response into the buffer
            @buffer << build_response(obj['id'], resp, 0, nil)
          end
        else
          # It's the response

          if obj.has_key?('error')
            err_code = obj['error'][0]
            err_msg = obj['error'][1]
          end

          result_object = lookup_table[obj['id']]
          if !result_object.nil?
            result_object.set_result(obj['result'], err_code, err_msg)
          else
            puts "Received unexpected response: #{obj['id']}, #{obj['result']}, #{err_code}, #{err_msg}";
          end
        end
      end
    end
  end

  def build_request(request_id, method, args)
    request = {
      'id' => request_id,
      'method' => method,
      'params' => args
    }
    return "#{request.to_json}\n"
  end

  def build_response(request_id, result, err_code, err_msg)
    if !err_code.nil? || !err_msg.nil?
      response = {
        'id' => request_id,
        'result' => nil,
        'error' => [err_code.to_i, err_msg.to_s, '']
      }
    else
      response = {
        'id' => request_id,
        'result' => result,
        'error' => nil
      }
    end
    return "#{response.to_json}\n"
  end
end
