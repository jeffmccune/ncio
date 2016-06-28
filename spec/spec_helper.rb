$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'simplecov'
SimpleCov.start do
  add_filter '/.bundle/'
  add_filter '/lib/trollop.rb'
end
require 'ncio'
require 'ncio/version'
require 'ncio/api/v1'
require 'ncio/api'
require 'ncio/http_client'

def fixture(name)
  File.read(File.join(File.dirname(__FILE__), "/fixtures/#{name}"))
end
