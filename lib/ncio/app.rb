# rubocop:disable Style/IndentationWidth
require 'ncio'
require 'ncio/support'
require 'ncio/support/option_parsing'
require 'ncio/trollop'
require 'ncio/version'
require 'ncio/api/v1'
require 'uri'
require 'socket'

module Ncio
##
# The main Application class.  Intended to be instantiated and called with
# using the `run` method by the `ncio` bin script.
class App
  # rubocop:enable Style/IndentationWidth
  # include support methods (option handling, logging, I/O helpers)
  include Ncio::Support
  include Ncio::Support::OptionParsing

  ##
  # @param [Array] argv The argument vector, passed to the option parser.
  #
  # @param [Hash] env The environment hash, passed to the option parser to
  #   supply defaults not specified on the command line argument vector.
  #
  # @return [Ncio::App] the application instance.
  def initialize(argv = ARGV.dup, env = ENV.to_hash)
    @argv = argv
    @env = env
    reset!
  end

  ##
  # Reset all state associated with this application instance.
  def reset!
    reset_options!
    reset_logging!(opts)
    @api = nil
  end

  ##
  # Run the application instance.  This method is responsible for the
  # application lifecycle.  Command line arguments are parsed, unspecified
  # options are read from the environment, and the specified subcommand is
  # executed.
  #
  # @return [Fixnum] the exit code to pass to Kernel.exit in the calling
  #   script.
  def run
    case opts[:subcommand]
    when 'backup'
      backup_groups if opts[:groups]
      return 0
    when 'restore'
      restore_groups if opts[:groups]
      return 0
    end
  end

  ##
  # Backup all groups in a manner suitable for the node classification hierarchy
  # import. See:
  # [NC Groups](https://docs.puppet.com/pe/2016.1/nc_groups.html#get-v1groups)
  def backup_groups
    debug "GET #{uri}/groups"
    str = JSON.pretty_generate(api.groups)
    debug "Write #{str.bytesize} bytes to #{file} ..."
    write_output(str, map_file_option(file))
    info 'Backup completed successfully!'
  end

  ##
  # Restore all groups in a manner suitable for the node classification
  # hierarchy import. See: [NC Import
  # Hierarchy](https://docs.puppet.com/pe/2016.1/nc_import-hierarchy.html)
  def restore_groups
    api = self.api
    debug "Open #{file} for streaming ..."
    input_stream(map_file_option(file)) do |stream|
      debug "POST #{uri}/import-hierarchy"
      api.import_hierarchy(stream)
    end
    info 'Successfully restored node classification groups!'
  end
end
end
