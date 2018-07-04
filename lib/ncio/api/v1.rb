require 'ncio/api'
require 'ncio/http_client'
require 'ncio/support'
require 'ncio/support/retry_action'
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
      class ApiAuthenticationError < RuntimeError; end

      DEFAULT_HEADERS = {
        'Content-Type' => 'application/json',
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

      def log
        Ncio::Support.log
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
      # Make a request respecting the timeout global option
      #
      # Assumes the timeout value is available in opts[:connect_timeout]
      def request_with_timeout(req)
        params = {
          timeout: opts[:connect_timeout],
          retry_exceptions: [Errno::ECONNREFUSED],
          log: self.log,
        }
        Ncio::Support::RetryAction.retry_action(params) do
          connection.request(req)
        end
      end

      ##
      # Make a request without a timeout
      def request_without_timeout(req)
        connection.request(req)
      end

      ##
      # Make a request, return a response
      def request(req)
        if opts[:retry_connections]
          request_with_timeout(req)
        else
          request_without_timeout(req)
        end
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
        resp = request(req)
        obj = if resp.code == '200'
                JSON.parse(resp.body)
              else
                raise_on_non_200(resp, 200)
              end
        obj
      end

      ##
      # Handle a non 200 response.
      def raise_on_non_200(resp, expected_code=200)
        if resp.code == '401' && %r{rbac/user-unauthenticated}.match(resp.body)
          obj = JSON.parse(resp.body)
          msg = obj['msg'] || '401 User Unauthenticated Error'
          raise ApiAuthenticationError, msg
        else
          msg = "Expected #{expected_code} response, got #{resp.code} "\
                "body: #{resp.body}"
          raise ApiError, msg
        end
      end

      ##
      # Import all of the classification groups using the POST
      # /v1/import-hierarchy endpoint.  See: [NC Import
      # Hierarchy](https://docs.puppet.com/pe/2016.1/nc_import-hierarchy.html)
      #
      # @return [Boolean] true if the upload was successful
      def import_hierarchy(stream)
        uri = build_uri('import-hierarchy')
        req = Net::HTTP::Post.new(uri, DEFAULT_HEADERS)
        req['Transfer-Encoding'] = ['chunked']
        req.body_stream = stream
        resp = request(req)
        return true if resp.code == '204'
        raise_on_non_200(resp, 204)
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
