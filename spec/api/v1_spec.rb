require 'spec_helper'
require 'ncio/api/v1'

describe 'Ncio::Api::V1' do
  context 'with default options' do
    let :opts do
      {
        uri: 'https://foo.acme.mock:14433/classifier-api/v1',
        cert: '/tmp/cert.pem',
        key: '/tmp/key.pem',
        cacert: '/tmp/ca.pem'
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

      context 'valid response' do
        let :resp do
          body = fixture('api_response_groups_default.json')
          double('response', code: '200', body: body)
        end

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
    end
  end
end
