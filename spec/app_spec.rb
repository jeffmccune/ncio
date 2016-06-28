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

  describe '#version' do
    it "is Ncio::Version (#{Ncio::VERSION})" do
      expect(subject.version).to eq(Ncio::VERSION)
    end
  end
end
