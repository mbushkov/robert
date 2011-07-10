$: << File.expand_path("../lib", __FILE__)

require 'rubygems'
require 'bundler'
Bundler.setup

RSpec.configure do |config|
  config.mock_framework = :flexmock
end
