require 'spec_helper'
require 'ncio/http_client'

ssldir = '/etc/puppetlabs/puppet/ssl'

describe 'Ncio::HttpClient' do
  context 'with default options' do
    subject do
      Ncio::HttpClient.new
    end

    describe '#initialize' do
      it "sets host to Socket.gethostname (#{Socket.gethostname})" do
        expect(subject.host).to eq(Socket.gethostname)
      end

      it 'sets port to 4433' do
        expect(subject.port).to eq(4433)
      end

      it 'sets use_ssl to true' do
        expect(subject.use_ssl).to be(true)
      end

      cert = "#{ssldir}/certs/#{Socket.gethostname}.pem"
      it "sets cert to #{cert}" do
        expect(subject.cert).to eq(cert)
      end

      key = "#{ssldir}/private_keys/#{Socket.gethostname}.pem"
      it "sets key to #{key}" do
        expect(subject.key).to eq(key)
      end

      cacert = "#{ssldir}/certs/ca.pem"
      it "sets cacert to #{cacert}" do
        expect(subject.cacert).to eq(cacert)
      end

      it 'sets protocol to https' do
        expect(subject.protocol).to eq('https')
      end
    end

    describe '#request' do
      before :each do
        # Stub out the PEM file reads
        allow(subject).to receive(:read_cert).and_return(fixture('ssl/crt'))
        allow(subject).to receive(:read_key).and_return(fixture('ssl/key'))
        # Stub out the CA Cert file read
        store = OpenSSL::X509::Store.new
        allow(store).to receive(:add_file).with(subject.cacert)
        allow(subject).to receive(:ssl_store).and_return(store)
        # Stub out the Net::HTTP instance to prevent a socket connection
        allow(Net::HTTP).to receive(:new).and_return(http)
      end

      let :http do
        # Stub out the Net::HTTP instance so we don't open a TCP connection
        instance_spy(Net::HTTP)
      end

      let :req do
        Net::HTTP::Get.new('/')
      end

      it 'passes requests to the http instance' do
        subject.request(req)
        expect(http).to have_received(:request).with(req, nil)
      end
    end

    describe '#uri' do
      it 'returns https://#{Socket.gethostname}:4433' do
        expect(subject.uri.to_s).to eq("https://#{Socket.gethostname}:4433")
      end

      it 'returns a URI instance' do
        expect(subject.uri).to be_a_kind_of(URI)
      end
    end
  end
end
