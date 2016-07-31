require 'ncio/version'
require 'socket'

# rubocop:disable Metrics/ModuleLength
module Ncio
  module Support
    ##
    # Support methods intended to be mixed into the application class.  These
    # methods are specific to command line parsing.  The model is [GLOBAL
    # OPTIONS] SUBCOMMAND [SUBCOMMAND OPTIONS]
    #
    # Configuration state parsed from options is intended to be stored in a
    # @opts hash and injected into dependencies, like API instances.
    module OptionParsing
      attr_reader :argv, :env, :opts

      ##
      # Reset the @opts instance variable by parsing @argv and @env.  Operates
      # against duplicate copies of the argument vector avoid side effects.
      #
      # @return [Hash<Symbol, String>] Options hash
      def reset_options!
        @opts = parse_options(argv, env)
      end

      ##
      # Parse options using the argument vector and the environment hash as
      # input. Option parsing occurs in two phases, first the global options are
      # parsed. These are the options specified before the subcommand.  The
      # subcommand, if any, is matched, and subcommand specific options are then
      # parsed from the remainder of the argument vector.
      #
      # @param [Array] argv The argument vector, passed to the option parser.
      #
      # @param [Hash] env The environment hash, passed to the option parser to
      #   supply defaults not specified on the command line argument vector.
      #
      # @return [Hash<Symbol, String>] options hash
      def parse_options(argv, env)
        argv_copy = argv.dup
        opts = parse_global_options!(argv_copy, env)
        subcommand = parse_subcommand!(argv_copy)
        opts[:subcommand] = subcommand
        sub_opts = parse_subcommand_options!(subcommand, argv_copy, env)
        opts.merge!(sub_opts)
        opts
      end

      ##
      # Parse out the global options, the ones specified between the main
      # executable and the subcommand argument.
      #
      # Modifies argv as a side effect, shifting elements from the array until
      # the first unknown option is found, which is assumed to be the subcommand
      # name.
      #
      # @return [Hash<Symbol, String>] Global options
      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def parse_global_options!(argv, env)
        semver = Ncio::VERSION
        host = Socket.gethostname
        Ncio::Trollop.options(argv) do
          stop_on_unknown
          version "ncio #{semver} (c) 2016 Jeff McCune"
          banner BANNER
          uri_dfl = env['NCIO_URI'] || "https://#{host}:4433/classifier-api/v1"
          opt :uri, 'Node Classifier service uri '\
            '{NCIO_URI}', default: uri_dfl
          opt :cert, CERT_MSG, default: env['NCIO_CERT'] || CERT_DEFAULT
          opt :key, KEY_MSG, default: env['NCIO_KEY'] || KEY_DEFAULT
          opt :cacert, CACERT_MSG, default: env['NCIO_CACERT'] || CACERT_DEFAULT
          log_msg = 'Log file to write to or keywords '\
            'STDOUT, STDERR {NCIO_LOGTO}'
          opt :logto, log_msg, default: env['NCIO_LOGTO'] || 'STDERR'
          opt :syslog, 'Log to syslog', default: true, conflicts: :logto
          opt :verbose, 'Set log level to INFO'
          opt :debug, 'Set log level to DEBUG'
          opt :retry_connections, 'Retry API connections, '\
              'e.g. waiting for the service to come online. '\
              '{NCIO_RETRY_CONNECTIONS}',
              default: (env['NCIO_RETRY_CONNECTIONS'] == 'true') || false
          opt :connect_timeout, 'Retry <i> seconds if --retry-connections=true '\
              '{NCIO_CONNECT_TIMEOUT}',
              default: env['NCIO_CONNECT_TIMEOUT'] || CONNECT_TIMEOUT_DEFAULT
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      ##
      # Extract the subcommand, if any, from the arguments provided.  Modifies
      # argv as a side effect, shifting the subcommand name if it is present.
      #
      # @return [String] The subcommand name, e.g. 'backup' or 'restore', or
      #   false if no arguments remain in the argument vector.
      def parse_subcommand!(argv)
        argv.shift || false
      end

      ##
      # Parse the subcommand options.  This method branches out because each
      # subcommand can have quite different options, unlike global options which
      # are consistent across all invocations of the application.
      #
      # Modifies argv as a side effect, shifting all options as things are
      # parsed.
      #
      # @return [Hash<Symbol, String>] Subcommand specific options hash
      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def parse_subcommand_options!(subcommand, argv, env)
        case subcommand
        when 'backup', 'restore'
          Ncio::Trollop.options(argv) do
            banner "Node Classification #{subcommand} options:"
            groups_msg = 'Operate against NC groups.  See: https://goo.gl/QD6ZdW'
            opt :groups, groups_msg, default: true
            file_msg = 'File to operate against {NCIO_FILE} or STDOUT, STDERR'
            file_default = FILE_DEFAULT_MAP[subcommand]
            opt :file, file_msg, default: env['NCIO_FILE'] || file_default
          end
        when 'transform'
          opts = Ncio::Trollop.options(argv) do
            banner "Node Classification transformations\n"\
              'Note: Currently only Monolithic (All-in-one) deployments are '\
              "supported.\n\nTransformation matches against class names "\
              'assigned to groups.  Transformation of hostnames happen '\
              'against rules assigned to groups and class parameters for '\
              "matching classes.\n\nOptions:"
            hostname_msg = 'Replace the fully qualified domain name on the '\
              'left with the right, separated with a : '\
              'e.g --hostname master1.acme.com:master2.acme.com'
            opt :class_matcher, 'Regexp matching classes assigned to groups. '\
                'Passed to Regexp.new()',
                default: '^puppet_enterprise'
            opt :input, 'Input file path or keywords STDIN, STDOUT, STDERR',
                default: 'STDIN'
            opt :output, 'Output file path or keywords STDIN, STDOUT, STDERR',
                default: 'STDOUT'
            opt :hostname, hostname_msg, type: :strings, multi: true,
                                         required: true
          end
          opts[:matcher] = Regexp.new(opts[:class_matcher])
          if opts[:hostname_given]
            hsh = map_hostnames(opts[:hostname].flatten)
            opts.merge!(hostname_map: hsh)
          end
        else
          Ncio::Trollop.die "Unknown subcommand: #{subcommand.inspect}"
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      ##
      # Map an array of hostnames separated by a colon.  The left is the key of
      # the map, the right is the value.  The Hash returned is "smart" in that a
      # key that does not exist will return a value matching the key.
      #
      # @param [Array<String>] hostnames
      #
      # @return [Hash<String, String>] Hash of hostnames, left as key, right as
      #   value.
      def map_hostnames(hostnames)
        smart_map = Hash.new { |_, key| key }
        hostnames.each_with_object(smart_map) do |pair, hsh|
          (k, v) = pair.split(':')
          hsh[k] = v
          hsh
        end
      end

      BANNER = <<-'EOBANNER'.freeze
usage: ncio [GLOBAL OPTIONS] SUBCOMMAND [ARGS]
Sub Commands:

  backup     Backup Node Classification resources
  restore    Restore Node Classification resources
  transform  Transform a backup, replacing hostnames

Quick Start: On the host of the Node Classifier service, as root or pe-puppet
(to read certs and keys)

    /opt/puppetlabs/puppet/bin/ncio backup > groups.$(date +%s).json
    /opt/puppetlabs/puppet/bin/ncio restore < groups.1467151827.json

Transformation:

    ncio --uri https://master1.puppet.vm:4433/classification-api/v1 backup \
     | ncio transform --hostname master1.puppet.vm:master2.puppet.vm \
     | ncio --uri https://master2.puppet.vm:4433/classification-api/v1 restore

Global options: (Note, command line arguments supersede ENV vars in {}'s)
      EOBANNER

      SSLDIR = '/etc/puppetlabs/puppet/ssl'.freeze
      CERT_MSG = 'White listed client SSL cert {NCIO_CERT} '\
        'See: https://goo.gl/zCjncC'.freeze
      CERT_DEFAULT = (SSLDIR + '/certs/'\
                      'pe-internal-orchestrator.pem').freeze
      KEY_MSG = 'Client RSA key, must match certificate '\
        '{NCIO_KEY}'.freeze
      KEY_DEFAULT = (SSLDIR + '/private_keys/'\
                     'pe-internal-orchestrator.pem').freeze
      CACERT_MSG = 'CA Cert to authenticate the service uri '\
        '{NCIO_CACERT}'.freeze
      CACERT_DEFAULT = (SSLDIR + '/certs/ca.pem').freeze

      # Map is indexed by the subcommand
      FILE_DEFAULT_MAP = { 'backup' => 'STDOUT', 'restore' => 'STDIN' }.freeze

      CONNECT_TIMEOUT_DEFAULT = 120
    end
  end
end
# rubocop:enable Metrics/ModuleLength
