$: << File.join(File.dirname(__FILE__), "..", "lib")

RSpec.configure do |config|
  config.mock_framework = :flexmock
end
