# frozen_string_literal: true

require 'local_tunnel'

class LocalTunnel::CLI
  def initialize(port: 8000, verbose: false)
    @options           = {}
    @options[:port]    = port
    @options[:verbose] = verbose
  end

  def option
    @options
  end

  def start
    LocalTunnel::Tunnel.new(debug: @options[:verbose]).start(option[:port]).wait
  end

  class << self
    def start(argv)
      options = {}

      while argv.size > 0 && argv[0].start_with?('-') && argv[0] != '--'
        case argv[0]
        when '-v'
          options[:verbose] = true
          argv.shift
        else
          $stderr.write("#{program_name}: illegal option -- #{argv[0]}\n")
          $stderr.write("#{usage}\n")
          exit SysExits::USAGE
        end
      end

      begin
        options[:port] = Integer(argv[0]) if argv[0]
      rescue TypeError, ArgumentError
        $stderr.write("#{usage}\n")
        exit SysExits::USAGE
      end

      new(options).start
    end

    def program_name
      File.basename($PROGRAM_NAME)
    end

    def usage
      "usage: #{program_name} [-v] [port]"
    end
  end

  module SysExits
    OK          = 0
    USAGE       = 64
    DATAERR     = 65
    NOINPUT     = 66
    NOUSER      = 67
    NOHOST      = 68
    UNAVAILABLE = 69
    SOFTWARE    = 70
    OSERR       = 71
    OSFILE      = 72
    CANTCREAT   = 73
    IOERR       = 74
    TEMPFAIL    = 75
    PROTOCOL    = 76
    NOPERM      = 77
    CONFIG      = 78
  end
end
