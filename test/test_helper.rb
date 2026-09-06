ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Minitest 6 dropped minitest/mock, so there is no Object#stub any
    # more. This stands in for it: swap a singleton method for the
    # duration of the block, mainly to keep tests off the network.
    #
    #   stub_method(Http, :get, returns: FEED) { ... }
    #   stub_method(Http, :get, raises: Http::Error.new("503")) { ... }
    def stub_method(object, name, returns: nil, raises: nil)
      singleton = object.singleton_class
      original  = singleton.instance_method(name)

      singleton.define_method(name) do |*, **|
        raise raises if raises

        returns
      end

      yield
    ensure
      singleton.define_method(name, original)
    end
  end
end
