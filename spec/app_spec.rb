require 'spec_helper'
require 'ncio/app'

describe Ncio::App do
  subject do
    described_class.new(argv, env)
  end

  let :argv do
    %w(--debug backup)
  end

  let :env do
    Hash.new
  end

  describe 'backup subcommand, typical usage' do
    let :argv do
      %w(--debug backup --file /tmp/foo.json)
    end

    describe '#run' do
      it 'responds to #run' do
        expect(subject).to respond_to(:run)
      end
    end
  end

  context 'When a timeout expired while trying to connect occurs' do
    let :argv do
      %w(--connect-timeout 5 backup)
    end
    # Mock the API call to thrown a conn refused
    # Stub out the timer to not wait?
    it 'prints a friendly error message' do
      excp = Ncio::Support::RetryAction::RetryException::Timeout
      msg = 'ERROR: Timeout expired connecting to the console service.  Verify it is up and running.'
      allow(subject).to receive(:backup_groups).and_raise excp
      expect(subject).to receive(:fatal).with(msg)
      subject.run
    end
  end

  describe '#version' do
    it "is Ncio::Version (#{Ncio::VERSION})" do
      expect(subject.version).to eq(Ncio::VERSION)
    end
  end
end
