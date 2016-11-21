require 'net/http'
require 'socket'
require 'openssl'

module Ncio
  ##
  # HttpClient provides a Net::HTTP instance pre-configured to communicate with
  # the Puppet Node Classification Service.  The client will return Ruby native
  # objects where possible, parsing JSON responses from the service.
  #
  # This client implements v1 of the [Node Classification
  # API](https://docs.puppet.com/pe/2016.1/nc_index.html).
  class HttpClient
    attr_reader :host
    attr_reader :port
    attr_reader :use_ssl
    attr_reader :cert
    attr_reader :key
    attr_reader :cacert
    attr_reader :protocol

    # ApiError is raised when there are errors in the REST API repsonse.
    class ApiError < RuntimeError; end

    ssldir = '/etc/puppetlabs/puppet/ssl'
    OPTION_DEFAULTS = {
      host: Socket.gethostname,
      port: 4433,
      use_ssl: true,
      cert: "#{ssldir}/certs/#{Socket.gethostname}.pem",
      key: "#{ssldir}/private_keys/#{Socket.gethostname}.pem",
      cacert: ssldir + '/certs/ca.pem'
    }.freeze

    ##
    # initialize a new HttpClient instance
    #
    # @param [Hash] opts Options
    #
    # @option opts [String] :host The API host, e.g. `"master1.puppet.vm"`.
    #   Defaults to the local hostname returned by `Socket.gethostname`
    #
    # @option opts [Fixnum] :port The API tcp port, Defaults to `4433`
    #
    # @option opts [String] :cert The path to the PEM encoded client
    #   certificate.  Defaults to
    #   `"/etc/puppetlabs/puppet/ssl/certs/$FQDN.pem"`
    #
    # @option opts [String] :key The path to the PEM encoded RSA private key
    #   used for the SSL client connection.  Defaults to
    #   `"/etc/puppetlabs/puppet/ssl/private_keys/$FQDN.pem"`
    #
    # @option opts [String] :cacert The path to the PEM encoded CA certificate
    #   used to authenticate the service URL.  Defaults to
    #   `"/etc/puppetlabs/puppet/ssl/certs/ca.pem"`
    def initialize(opts = {})
      opts = OPTION_DEFAULTS.merge(opts)
      @use_ssl = opts[:use_ssl]
      @host = opts[:host]
      @port = opts[:port]
      @cert = opts[:cert]
      @key = opts[:key]
      @cacert = opts[:cacert]
      @protocol = use_ssl ? 'https' : 'http'
    end

    ##
    # make a request, pass through to Net::HTTP#request
    #
    # @param [Net::HTTPRequest] req The HTTP request, e.g. an instance of
    #   `Net::HTTP::Get`, `Net::HTTP::Post`, or `Net::HTTP::Head`.
    #
    # @param [String] body The request body, if any.
    #
    # @return [Net::HTTPResponse] response
    def request(req, body = nil)
      http.request(req, body)
    end

    ##
    # Provide a URL to the endpoint this client connects to.  This is intended
    # to construct URL's and add query parameters easily.
    #
    # @return [URI] the URI of the server this client connects to.
    def uri
      return @uri if @uri
      @uri = URI("#{protocol}://#{host}:#{port}")
    end

    private

    ##
    # return a memoized HTTP object instance configured with the SSL client
    # certificate and ready to authorize the peer service
    #
    # TODO: Add revocation checking.  See: [puppet/ssl/host.rb line
    # 263](https://github.com/puppetlabs/puppet/blob/4.5.2/lib/puppet/ssl/host.rb#L263)
    #
    # @return [Net::HTTP]
    def http
      return @http if @http
      client = Net::HTTP.new(uri.host, uri.port)
      @http = if use_ssl
                setup_ssl(client)
              else
                client
              end
      @http
    end

    ##
    # Configure this client to use SSL
    #
    # @param [Net::HTTP] http The http instance to configure to use SSL
    #
    # @return [Net::HTTP] configured with SSL certificates passed to
    # initializer.
    def setup_ssl(http)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      # Setup the SSL store used for this connection
      ssl_store = ssl_store()
      ssl_store.purpose = OpenSSL::X509::PURPOSE_ANY
      ssl_store.add_file(cacert)
      http.cert_store = ssl_store
      # PEM files
      http.cert = OpenSSL::X509::Certificate.new(read_cert)
      http.key = OpenSSL::PKey::RSA.new(read_key)
      http.ca_file = cacert
      http
    end

    # helper method to stub the OpenSSL Store
    def ssl_store
      OpenSSL::X509::Store.new
    end
    ##

    # helper method to stub the cert in the tests
    def read_cert
      File.read(cert)
    end

    # helper method to stub the cert in the tests
    def read_key
      File.read(key)
    end
  end
end
