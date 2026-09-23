require "test_helper"

class JobSearchServiceTest < ActiveSupport::TestCase
  test "builds keyword query with active and optional exact filters" do
    response = { "hits" => { "hits" => [ { "_id" => "42" }, { "_id" => "7" } ] } }
    request = nil
    search = ->(**arguments) { request = arguments; response }

    with_stubbed_method(OPENSEARCH_CLIENT, :search, search) do
      ids = JobSearchService.new(query: "rails developer", location: "Lahore", job_type: "remote",
                                 experience_level: "junior").job_ids
      assert_equal [ 42, 7 ], ids
    end

    assert_equal Rails.configuration.x.opensearch_index, request[:index]
    assert_equal 1000, request[:body][:size]
    assert_equal false, request[:body][:_source]
    query = request[:body][:query][:bool]
    assert_equal "rails developer", query[:must][:multi_match][:query]
    assert_equal %w[title^3 description company_name location skills], query[:must][:multi_match][:fields]
    assert_equal [
      { term: { status: "active" } },
      { term: { "location.keyword" => "Lahore" } },
      { term: { job_type: "remote" } },
      { term: { experience_level: "junior" } }
    ], query[:filter]
  end
end
