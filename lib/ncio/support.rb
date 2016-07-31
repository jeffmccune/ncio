require 'json'
require 'logger'
require 'stringio'
require 'syslog/logger'

module Ncio
  ##
  # Support module to mix into other classes, particularly the application and
  # API classes.  This support module provides a centralized logging
  # configuration, and common methods to access configuration options about the
  # behavior of the program.
  module Support
    attr_reader :opts

    ##
    # Reset the global logger instance and return it as an object.
    #
    # @return [Logger] initialized logging instance
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
      @log || reset_logging!
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
      when 'STRING' then StringIO.new
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
      data = { error: e.class.to_s, message: e.message, backtrace: e.backtrace }
      JSON.pretty_generate(data)
    end

    ##
    # Top level exception handler and friendly error message handler.
    def friendly_error(e)
      case e
      when Ncio::Support::RetryAction::RetryException::Timeout
        'Timeout expired connecting to the console service.  Verify it is up and running.'
      when OpenSSL::SSL::SSLError
        friendly_ssl_error(e)
      when Ncio::Api::V1::ApiAuthenticationError
        'Make sure the --cert option value is listed in the certificate whitelist, '\
        'and you are able to run puppet agent --test on the master. '\
        'The certificate whitelist on the master is located at '\
        '/etc/puppetlabs/console-services/rbac-certificate-whitelist'
      else
        e.message
      end
    end

    ##
    # Handle SSL errors as a special case
    def friendly_ssl_error(e)
      case e.message
      when %r{read server hello A}
        'The socket connected, but there is no SSL service on the other side. '\
        'This is often the case with TCP forwarding, e.g. in Vagrant '\
        'or with SSH tunnels.'
      when %r{state=error: certificate verify failed}
        'The socket connected, but the certificate presented by the service could not '\
        'be verified.  Make sure the value of the --cacert option points to an identical '\
        'copy of the /etc/puppetlabs/puppet/ssl/certs/ca.pem file from the master.'
      when %r{returned=5 errno=0 state=SSLv3 read finished A}
        "The socket connected, but got back SSL error: #{e.message} "\
        'This usually means the value of the --cert and --key options are certificates '\
        'which are not signed by the same CA the service trusts.  This can often happen '\
        'if the service has recently been re-installed.  Please obtain a valid cert and key '\
        'and try again.'
      else
        "SSL Error: The socket is listening but something went wrong: #{e.message}"
      end
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
