require 'ncio/api'
require 'ncio/http_client'
require 'uri'
require 'socket'
require 'json'

module Ncio
  module Api
    ##
    # Node Classifier API Version 1
    #
    # See [Groups
    # endpoint](https://docs.puppet.com/pe/2016.1/nc_groups.html#get-v1groups)
    class V1
      attr_reader :host
      attr_reader :port
      attr_reader :opts

      class ApiError < RuntimeError; end

      DEFAULT_HEADERS = {
        'Content-Type' => 'application/json'
      }.freeze

      ##
      # Initialize and return a new API instance.
      #
      # @param [Hash<Symbol, String>] The global options hash created by the
      #   application instanece.
      def initialize(opts)
        @opts = opts
        uri = URI(opts[:uri])
        @host = uri.host
        @port = uri.port
      end

      ##
      # Return a memoized HTTP connection
      def connection
        return @connection if @connection
        conn_opts = {
          host: host,
          port: port,
          cert: opts[:cert],
          key: opts[:key],
          cacert: opts[:cacert]
        }
        @connection = Ncio::HttpClient.new(conn_opts)
      end

      ##
      # Return all of the groups currently defined in the node classifier API.
      #
      # @param [Boolean] inherited If set to any value besides 0 or false, the
      #   node group will include the classes, class parameters, and variables
      #   that it inherits from its ancestors.
      #
      # @return [Array]
      def groups(inherited = false)
        uri = build_uri('groups', inherited: inherited.to_s)
        req = Net::HTTP::Get.new(uri, DEFAULT_HEADERS)
        resp = connection.request(req)
        if resp.code == '200'
          obj = JSON.parse(resp.body)
        else
          msg = "Expected 200 response, got #{resp.code} body: #{resp.body}"
          raise ApiError, msg
        end
        obj
      end

      ##
      # Return a URI instance with the given path and parameters.  The
      #   connection base URI is used to construct the full URI to the service.
      #
      # @param [String] path The path relative to the classifier base service
      #   path and the API version, e.g. 'groups'.
      #
      # @param [Hash] params The query parameters to encode into the URI, e.g.
      #   `{inherited: 'false'}`.
      #
      # @return [URI] The API uri with query parameters and a fully constructed
      #   path.
      def build_uri(path, params = {})
        uri = connection.uri
        uri.path = "/classifier-api/v1/#{path}"
        uri.query = URI.encode_www_form(params)
        uri
      end
    end
  end
end
