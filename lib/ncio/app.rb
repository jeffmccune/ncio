# rubocop:disable Style/IndentationWidth
require 'ncio'
require 'ncio/support'
require 'ncio/support/option_parsing'
require 'ncio/support/transform'
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
  include Ncio::Support::Transform

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
  # rubocop:disable Metrics/MethodLength
  def run
    case opts[:subcommand]
    when 'backup'
      backup_groups if opts[:groups]
      return 0
    when 'restore'
      restore_groups if opts[:groups]
      return 0
    when 'transform'
      transform_groups
      return 0
    end
  end
  # rubocop:enable Metrics/MethodLength

  ##
  # Backup all groups in a manner suitable for the node classification hierarchy
  # import. See:
  # [NC Groups](https://docs.puppet.com/pe/2016.1/nc_groups.html#get-v1groups)
  # rubocop:disable Metrics/AbcSize
  def backup_groups
    warn "Starting Node Classification Backup using GET #{uri}/groups"
    groups = api.groups
    debug "Number of groups retrieved: #{groups.size}"
    str = JSON.pretty_generate(groups)
    debug "Write #{str.bytesize} bytes of JSON to #{file} ..."
    write_output(str, map_file_option(file))
    warn 'Finished Node Classification Backup '\
      "STATUS=OK BYTESIZE=#{str.bytesize} GROUPCOUNT=#{groups.size} "\
      "OUTPUT=#{file}"
  rescue Exception => e
    fatal "ERROR Obtaining backup: #{format_error e}"
    raise e
  end
  # rubocop:enable Metrics/AbcSize

  ##
  # Restore all groups in a manner suitable for the node classification
  # hierarchy import. See: [NC Import
  # Hierarchy](https://docs.puppet.com/pe/2016.1/nc_import-hierarchy.html)
  def restore_groups
    warn 'Starting Node Classification Restore using '\
      "POST #{uri}/import-hierarchy"
    api = self.api
    debug "Open #{file} for streaming ..."
    input_stream(map_file_option(file)) do |stream|
      debug "POST #{uri}/import-hierarchy"
      api.import_hierarchy(stream)
    end
    warn 'Finished Node Classification Restore '\
      "STATUS=OK INPUT=#{file}"
  rescue Exception => e
    fatal "ERROR Restoring backup: #{format_error e}"
    raise e
  end

  ##
  # Transform a backup produced with backup_groups.  The transformation is
  # intended to allow restoration of the backup on PE Infrastructure cluster
  # different from the one the backup was produced on.
  #
  # Currently only one PE cluster type is supported, the Monolithic master type.
  # rubocop:disable Metrics/AbcSize
  def transform_groups
    # Read input
    groups = JSON.parse(input_stream(map_file_option(opts[:input]), &:read))
    groups.map! do |group|
      group_matches?(group) ? transform_group(group) : group
    end
    str = JSON.pretty_generate(groups)
    debug "Write #{str.bytesize} bytes to #{opts[:output]} ..."
    write_output(str, map_file_option(opts[:output]))
    info 'Transformation completed successful!'
  end
  # rubocop:enable Metrics/AbcSize
end
end
