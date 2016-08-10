require 'spec_helper'
require 'ncio/api/v1'

describe 'Ncio::Api::V1' do
  context 'with default options' do
    let :opts do
      {
        uri: 'https://foo.acme.mock:14433/classifier-api/v1',
        cert: '/tmp/cert.pem',
        key: '/tmp/key.pem',
        cacert: '/tmp/ca.pem',
        connect_timeout: 60
      }
    end
    subject do
      Ncio::Api::V1.new(opts)
    end

    describe '#initialize' do
      it 'sets host to foo.acme.mock' do
        expect(subject.host).to eq('foo.acme.mock')
      end

      it 'sets port to 14433' do
        expect(subject.port).to eq(14_433)
      end
    end

    describe '#request_with_timeout' do
      before :each do
        allow(Ncio::Support::RetryAction).to receive(:sleep)
        allow(Ncio::Support::RetryAction).to receive(:timedout?).and_return(false, false, false, true)
      end
      context 'when the service is down, Errno::ECONNREFUSED returned' do
        it 'retries the request' do
          exc = Errno::ECONNREFUSED
          msg = 'Connection refused - connect(2) for "localhost.spec" port 4433'
          conn = double('connection')
          req = double(Net::HTTP::Get)
          idx = 0
          allow(conn).to receive(:request) do
            idx = idx + 1
            raise exc, msg if idx < 4
            'some response'
          end

          allow(subject).to receive(:connection).and_return conn
          expect(subject.request_with_timeout(req)).to eq('some response')
        end
      end
    end

    describe '#connection' do
      it 'Passes host and port to Ncio::HttpClient.new' do
        opts = {
          host: subject.host,
          port: subject.port,
          cert: '/tmp/cert.pem',
          key: '/tmp/key.pem',
          cacert: '/tmp/ca.pem'
        }
        allow(Ncio::HttpClient).to receive(:new)
        subject.connection
        expect(Ncio::HttpClient).to have_received(:new).with(opts)
      end
    end

    describe '#groups' do
      before :each do
        uri = URI("https://#{subject.host}:#{subject.port}")
        conn = double('connection')
        allow(conn).to receive(:request).with(Net::HTTP::Get).and_return(resp)
        allow(conn).to receive(:uri).and_return(uri)
        allow(subject).to receive(:connection).and_return(conn)
      end

      let :resp do
        body = fixture('api_response_groups_default.json')
        double('response', code: '200', body: body)
      end

      context 'valid response' do
        it 'parses the JSON response' do
          expect(subject.groups).to eq(JSON.parse(resp.body))
        end
      end

      context 'invalid response' do
        let :resp do
          body = 'error'
          double('response', code: '401', body: body)
        end

        it 'raises an error with the code and body' do
          m = /Expected 200 response, got 401 body: error/
          expect { subject.groups }.to raise_error(m)
        end
      end

      context 'with :retry_connections option enabled' do
        subject do
          Ncio::Api::V1.new(opts.merge(retry_connections: true))
        end
        it 'calls retry_with_timeout' do
          expect(subject).to receive(:request_without_timeout).never
          expect(subject).to receive(:request_with_timeout).and_return(resp)
          subject.groups
        end
      end

      context 'with :retry_connections option enabled' do
        subject do
          Ncio::Api::V1.new(opts.merge(retry_connections: false))
        end
        it 'calls retry_with_timeout' do
          expect(subject).to receive(:request_without_timeout).and_return(resp)
          expect(subject).to receive(:request_with_timeout).never
          subject.groups
        end
      end

      context '(#7) when the service returns 401 Route requires authentication' do
        let :resp do
          body = JSON.dump({
            'kind' => 'puppetlabs.rbac/user-unauthenticated',
            'msg' => 'Route requires authentication',
            'redirect' => '/classifier-api/v1/groups?inherited=false',
          })
          double('response', code: '401', body: body)
        end
        it 'raises ApiAuthenticationError' do
          expect { subject.groups }.to raise_error(Ncio::Api::V1::ApiAuthenticationError)
        end
      end
    end
  end
end
