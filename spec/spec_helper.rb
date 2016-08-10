$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'simplecov'
SimpleCov.start do
  add_filter '/.bundle/'
  add_filter '/lib/ncio/trollop.rb'
end
require 'ncio'
require 'ncio/support'
require 'ncio/version'
require 'ncio/api/v1'
require 'ncio/api'
require 'ncio/http_client'

def fixture(name)
  File.read(File.join(File.dirname(__FILE__), "/fixtures/#{name}"))
end

# Stub out the logging to a string.  Logging really should be improved to inject
# a collector we can assert against.
RSpec.configure do |config|
  config.before :all do
    Ncio::Support.reset_logging!(logto: 'STRING')
  end
end
