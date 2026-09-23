ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def with_stubbed_method(object, name, replacement)
      original = object.method(name)
      object.define_singleton_method(name, &replacement)
      yield
    ensure
      object.define_singleton_method(name, original)
    end
  end
end
