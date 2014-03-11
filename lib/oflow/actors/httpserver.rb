
require 'socket'
require 'time'
require 'fcntl'

module OFlow
  module Actors

    class HttpServer < Trigger

      def initialize(task, options)
        super
        @sessions = { }
        
        @server = TCPServer.new(@port)
        @server.fcntl(Fcntl::F_SETFL, @server.fcntl(Fcntl::F_GETFL, 0) | Fcntl::O_NONBLOCK)
        @server_loop = Thread.start(self) do |me|
          Thread.current[:name] = me.task.full_name() + '-server'
          while Task::CLOSING != task.state
            begin
              session = @server.accept_nonblock()
              session.fcntl(Fcntl::F_SETFL, session.fcntl(Fcntl::F_GETFL, 0) | Fcntl::O_NONBLOCK)
              @count += 1
              req = read_req(session, @count)
              @sessions[@count] = session
              puts "*** #{req}"
              resp = {
                status: 200,
                body: nil,
                headers: {
                  'Content-Type' => 'text/html',
                }
              }
              box = new_event()
              box.contents[:request] = req
              box.contents[:response] = resp
              task.links.each_key do |key|
                continue if :success == key || 'success' == key
                begin
                  task.ship(key, box)
                rescue BlockedError => e
                  task.warn("Failed to ship timer #{box.contents} to #{key}. Task blocked.")
                rescue BusyError => e
                  task.warn("Failed to ship timer #{box.contents} to #{key}. Task busy.")
                end
              end
            rescue IO::WaitReadable, Errno::EINTR
              IO.select([@server], nil, nil, 0.5)
            rescue Exception => e
              task.handle_error(e)
            end
          end
        end
      end

      def perform(op, box)
        case op
        when :reply
          req_id = box.get(@req_id_path)
          if (session = @sessions[req_id]).nil?
            raise NotFoundError.new(task.full_name, 'session', req_id)
          end
          if (resp = box.get(@response_path)).nil?
            raise NotFoundError.new(task.full_name, 'response', @response_path)
          end
          body = resp[:body]
          body = '' if body.nil?
          status = resp[:status]
          headers = ["HTTP/1.1 #{status} {STATUS_MESSAGES[status]}"]
          resp[:headers].each do |k,v|
            headers << "#{k}: #{v}"
          end
          headers << "Content-Length: #{body.length}\r\n\r\n"
          session.puts headers.join("\r\n")
          session.puts body
          session.close
          @sessions.delete(req_id)
        when :skip
          req_id = box.get(@req_id_path)
          if (session = @sessions[req_id]).nil?
            raise NotFoundError.new(task.full_name, 'session', req_id)
          end
          @sessions.delete(req_id)
          # TBD options to set attributes
        else
          raise OpError.new(task.full_name, op)
        end
        task.ship(:success, Box.new(nil, box.tracker)) unless task.links[:success].nil?
      end

      def set_options(options)
        super
        @port = options.fetch(:port, 6060)
        @req_id_path = options.fetch(:req_id_path, 'request:id')
        @response_path = options.fetch(:response_path, 'response')
        @read_timeout = options.fetch(:read_timeout, 1.0)
      end

      def read_req(session, id)
        req = {
          id: id,
        }
        line = session.gets()
        parts = line.split(' ')
        req[:method] = parts[0]
        req[:protocol] = parts[2]
        path, arg_str = parts[1].split('?', 2)
        req[:path] = path
        args = nil
        unless arg_str.nil?
          args = arg_str.split('&').map { |pair| pair.split('=') }
        end
        req[:args] = args

        # Read the rest of the lines and the body if there is one.
        len = 0
        while line = session.gets()
          line.strip!
          break if 0 == line.size
          parts = line.split(':', 2)
          next unless 2 == parts.size
          key = parts[0]
          value = parts[1].strip()
          if 'Content-Length' == key
            value = value.to_i
            len = value
          end
          req[key] = value
        end
        req[:body] = read_timeout(session, len, @read_timeout) if 0 < len
        req
      end

      def read_timeout(session, len, timeout)
        str = ''
        done = Time.now() + timeout
        loop do
          begin
            str = session.readpartial(len, str)
            break if str.size == len
          rescue  Errno::EAGAIN => e
            raise e if IO.select([session], nil, nil, done - Time.now()).nil?
            retry
          end
        end
        str
      end

      STATUS_MESSAGES = {
        100 => 'Continue',
        101 => 'Switching Protocols',
        102 => 'Processing',
        200 => 'OK',
        201 => 'Created',
        202 => 'Accepted',
        203 => 'Non-Authoritative Information',
        204 => 'No Content',
        205 => 'Reset Content',
        206 => 'Partial Content',
        207 => 'Multi-Status',
        208 => 'Already Reported',
        226 => 'IM Used',
        300 => 'Multiple Choices',
        301 => 'Moved Permanently',
        302 => 'Found',
        303 => 'See Other',
        304 => 'Not Modified',
        305 => 'Use Proxy',
        306 => 'Switch Proxy',
        307 => 'Temporary Redirect',
        308 => 'Permanent Redirect',
        400 => 'Bad Request',
        401 => 'Unauthorized',
        402 => 'Payment Required',
        403 => 'Forbidden',
        404 => 'Not Found',
        405 => 'Method Not Allowed',
        406 => 'Not Acceptable',
        407 => 'Proxy Authentication Required',
        408 => 'Request Timeout',
        409 => 'Conflict',
        410 => 'Gone',
        411 => 'Length Required',
        412 => 'Precondition Failed',
        413 => 'Request Entity Too Large',
        414 => 'Request-URI Too Long',
        415 => 'Unsupported Media Type',
        416 => 'Requested Range Not Satisfiable',
        417 => 'Expectation Failed',
        418 => "I'm a teapot",
        419 => 'Authentication Timeout',
        420 => 'Method Failure',
        422 => 'Unprocessed Entity',
        423 => 'Locked',
        424 => 'Failed Dependency',
        425 => 'Unordered Collection',
        426 => 'Upgrade Required',
        428 => 'Precondition Required',
        429 => 'Too Many Requests',
        431 => 'Request Header Fields Too Long',
        440 => 'Login Timeout',
        444 => 'No Response',
        449 => 'Retry With',
        450 => 'Blocked by Windows Parental Controls',
        451 => 'Unavailable For Legal Reasons',
        494 => 'Request Header Too Large',
        495 => 'Cert Error',
        496 => 'No Cert',
        497 => 'HTTP tp HTTP',
        499 => 'Client Closed Request',
        500 => 'Internal Server Error',
        501 => 'Not Implemented',
        502 => 'Bad Gateway',
        503 => 'Service Unavailable',
        504 => 'Gateway Timeout',
        505 => 'HTTP Version Not Supported',
        506 => 'Variant Also Negotiates',
        507 => 'Insufficient Storage',
        508 => 'Loop Detected',
        509 => 'Bandwidth Limit Exceeded',
        510 => 'Not Extended',
        511 => 'Network Authentication Required',
        520 => 'Original Error',
        522 => 'Connection timed out',
        523 => 'Proxy Declined Request',
        524 => 'A timeout occurred',
        598 => 'Network read timeout error',
        599 => 'Network connect timeout error',
      }

    end # HttpServer
  end # Actors
end # OFlow
