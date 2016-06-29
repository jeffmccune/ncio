require 'logger'
require 'syslog/logger'
require 'json'

module Ncio
  ##
  # Support module to mix into other classes, particularly the application and
  # API classes.  This support module provides a centralized logging
  # configuration, and common methods to access configuration options about the
  # behavior of the program.
  module Support
    attr_reader :opts

    def self.reset_logging!(opts)
      logger = opts[:syslog] ? syslog_logger : stream_logger(opts)
      @log = logger
    end

    ##
    # Return a new Syslog::Logger instance configured for syslog output
    def self.syslog_logger
      # Use the daemon facility, matching Puppet behavior.
      Syslog::Logger.new('ncio', Syslog::LOG_DAEMON)
    end

    ##
    # Return a new Logger instance configured for file output
    def self.stream_logger(opts)
      out = map_file_option(opts[:logto])
      logger = Logger.new(out)
      logger.level = Logger::WARN
      logger.level = Logger::INFO if opts[:verbose]
      logger.level = Logger::DEBUG if opts[:debug]
      logger
    end

    ##
    # Logging is handled centrally, the helper methods will delegate to the
    # centrally configured logging instance.
    def self.log
      @log
    end

    ##
    # Map a file option to STDOUT, STDERR or a fully qualified file path.
    #
    # @param [String] filepath A relative or fully qualified file path, or the
    #   keyword strings 'STDOUT' or 'STDERR'
    #
    # @return [String] file path or $stdout or $sederr
    def self.map_file_option(filepath)
      case filepath
      when 'STDOUT' then $stdout
      when 'STDERR' then $stderr
      when 'STDIN' then $stdin
      else File.expand_path(filepath)
      end
    end

    def map_file_option(filepath)
      Ncio::Support.map_file_option(filepath)
    end

    def log
      Ncio::Support.log
    end

    ##
    # Reset the logging system, requires command line options to have been
    # parsed.
    #
    # @param [Hash<Symbol, String>] Options hash, passed to the support module
    def reset_logging!(opts)
      Ncio::Support.reset_logging!(opts)
    end

    ##
    # Memoized helper method to instantiate an API instance assuming options
    # are available.
    def api
      @api ||= Ncio::Api::V1.new(opts)
    end

    ##
    # Logs a message at the fatal (syslog err) log level
    def fatal(msg)
      log.fatal msg
    end

    ##
    # Logs a message at the error (syslog warning) log level.
    # i.e. May indicate that an error will occur if action is not taken.
    # e.g. A non-root file system has only 2GB remaining.
    def error(msg)
      log.error msg
    end

    ##
    # Logs a message at the warn (syslog notice) log level.
    # e.g. Events that are unusual, but not error conditions.
    def warn(msg)
      log.warn msg
    end

    ##
    # Logs a message at the info (syslog info) log level
    # i.e. Normal operational messages that require no action.
    # e.g. An application has started, paused or ended successfully.
    def info(msg)
      log.info msg
    end

    ##
    # Logs a message at the debug (syslog debug) log level
    # i.e.  Information useful to developers for debugging the application.
    def debug(msg)
      log.debug msg
    end

    def uri
      opts[:uri]
    end

    def file
      opts[:file]
    end

    ##
    # Helper method to write output, used for stubbing out the tests.
    #
    # @param [String, IO] output the output path or a IO stream
    def write_output(str, output)
      if output.is_a?(IO)
        output.puts(str)
      else
        File.open(output, 'w+') { |f| f.puts(str) }
      end
    end

    ##
    # Helper method to read from STDIN, or a file and execute an arbitrary block
    # of code.  A block must be passed which will recieve an IO object in the
    # event input is a readable file path.
    def input_stream(input)
      if input.is_a?(IO)
        yield input
      else
        File.open(input, 'r') { |stream| yield stream }
      end
    end

    ##
    # Format an exception for logging.  JSON is used to aid centralized log
    # systems such as Logstash and Splunk
    #
    # @param [Exception] e the exception to format
    def format_error(e)
      data = { error: "#{e.class}", message: e.message, backtrace: e.backtrace }
      JSON.pretty_generate(data)
    end

    ##
    # Return the application version as a Semantic Version encoded string
    #
    # @return [String] the version
    def version
      Ncio::VERSION
    end
  end
end
