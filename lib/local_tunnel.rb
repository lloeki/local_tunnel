# frozen_string_literal: true

module LocalTunnel; end

require 'net/http'
require 'uri'
require 'json'
require 'logger'

module LocalTunnel
  AssignedUrlInfo = Struct.new(
    :id,
    :url,
    :port,
    :max_conn_count,
  )

  SERVER = 'http://localtunnel.me/'

  class TunnelConn
    def initialize(rhost, rport, lport, id:, logger: nil)
      @rhost = rhost
      @rport = rport
      @lhost = 'localhost'
      @lport = lport
      @lrcount = 0
      @rlcount = 0
      @id = id
      @logger = logger || self.class.logger.dup
    end

    def start
      @rconn = rconnect
      @lconn = lconnect

      @lrthr = Thread.new do
        buf = String.new(capacity: 1024)
        loop do
          begin
            logger.debug(format("%03d lr: attempting read", @id))
            @lconn.readpartial(1024, buf)
          rescue EOFError
            logger.debug(format("%03d lr: read failed, reconnecting", @id))
            @lconn.close
            @lconn = lconnect
            retry
          end
          logger.debug(format("%03d lr:   read #{buf.size}", @id))

          begin
            logger.debug(format("%03d lr: attempting write", @id))
            s = @rconn.write(buf)
          rescue IOError
            logger.debug(format("%03d lr: write failed, reconnecting", @id))
            @rconn.close
            @rconn = rconnect
            retry
          end
          logger.debug(format("%03d lr:   write #{s}", @id))

          @lrcount += buf.size
          logger.debug(format("%03d lr:   total #{@lrcount}", @id))
          buf.clear
        end
      end

      @rlthr = Thread.new do
        buf = String.new(capacity: 1024)
        loop do
          begin
            logger.debug(format("%03d rl: attempting read", @id))
            @rconn.readpartial(1024, buf)
          rescue EOFError
            logger.debug(format("%03d rl: read failed, reconnecting", @id))
            @rconn.close
            @rconn = rconnect
            retry
          end
          logger.debug(format("%03d rl:   read #{buf.size}", @id))

          begin
            logger.debug(format("%03d rl: attempting write", @id))
            s = @lconn.write(buf)
          rescue IOError
            logger.debug(format("%03d rl: write failed, reconnecting", @id))
            @lconn.close
            @lconn = lconnect
            retry
          end
          logger.debug(format("%03d rl:   write #{s}", @id))

          @rlcount += buf.size
          logger.debug(format("%03d rl:   total #{@rlcount}", @id))
          buf.clear
        end
      end

      self
    end

    def wait
      [@lrthr, @rlthr].each(&:join)
      self
    end

    def stop
      [@lrthr, @rlthr].compact.each(&:kill)
      self
    end

    def rconnect
      TCPSocket.new(@rhost, @rport)
    end

    def lconnect
      TCPSocket.new(@lhost, @lport)
    end

    private

    def logger
      @logger
    end

    class << self
      def logger
        @logger ||= LocalTunnel.logger.dup
      end

      def logger=(value)
        @logger = value
      end
    end
  end

  class Tunnel
    def initialize(domain: nil, debug: false)
      @domain = domain
      @logger = self.class.logger.dup
      @logger.level = Logger::DEBUG if debug
    end

    def url
      assign_url! unless defined?(@url)
      @url
    end

    def port
      assign_url! unless defined?(@port)
      @port
    end

    def max_conn_count
      assign_url! unless defined?(@max_conn_count)
      @max_conn_count
    end

    def create(port)
      assign_url!
      logger.debug("#{url}, #{max_conn_count}")
      @max_conn_count.times do |i|
        @conns[i] = TunnelConn.new(URI(SERVER).host, @port, port, id: i)
        @conns[i].start
      end
    end

    def start(port)
      create(port)
      self
    end

    def wait
      @conns.compact.each(&:wait)
    end

    def stop
      @conns.compact.each(&:stop)
    end

    private

    def logger
      @logger
    end

    def assign_url!
      info = LocalTunnel.get_assigned_url(@domain)
      @url = info.url
      @max_conn_count = info.max_conn_count
      @port = info.port
      @conns = Array.new(@max_conn_count)
      info
    end

    class << self
      def logger
        @logger ||= LocalTunnel.logger.dup
      end

      def logger=(value)
        @logger = value
      end
    end
  end

  class << self
    def logger
      @logger ||= Logger.new(STDOUT).tap { |l| l.level = Logger:: WARN }
    end

    def logger=(value)
      @logger = value
    end

    def get_assigned_url(domain = nil)
      domain = '?new' unless domain

      Net::HTTP.start(URI(SERVER).hostname) do |http|
        req = Net::HTTP::Get.new(URI(SERVER) + domain)
        res = http.request(req)

        case res
        when Net::HTTPSuccess
          j = JSON.parse(res.body)
          AssignedUrlInfo.new(j['id'], j['url'], j['port'], j['max_conn_count'])
        else
          raise
        end
      end
    end
  end
end
