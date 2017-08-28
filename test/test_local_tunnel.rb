# frozen_string_literal: true

require 'minitest/autorun'
require 'local_tunnel'

require 'securerandom'
require 'uri'
require 'net/http'
require 'pry'
require 'pathname'

class TestLocalTunnel < MiniTest::Test
  def test_live_tunnel
    uuid = SecureRandom.uuid.encode('UTF-8')
    serve_dir = Pathname.new('test/serve')
    (serve_dir + uuid).open('wb') { |f| f.write(uuid) }
    LocalTunnel.logger = Logger.new(STDOUT).tap { |l| l.level = Logger::DEBUG }

    begin
      start_test_server(serve_dir, 8000, serve_dir + "#{uuid}.log")
      sleep 1

      t = LocalTunnel::Tunnel.new
      t.start(8000)

      res = Net::HTTP.get(URI(t.url) + uuid)
      assert_equal(uuid, res)
    ensure
      t.stop if t
      stop_test_server
    end
  end

  def start_test_server(path, port, out)
    @pid = Process.spawn(<<-EOS, [:out, :err] => out.to_s)
      ruby -rsinatra -e'set :public_folder, "#{path}"; set :port, #{port}'
    EOS
  end

  def stop_test_server
    Process.kill('TERM', @pid) if @pid
  end
end
