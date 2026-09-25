require "test_helper"

class JobSearchServiceTest < ActiveSupport::TestCase
  test "searches job details except description and status and applies exact filters" do
    response = { "hits" => { "hits" => [ { "_id" => "42" }, { "_id" => "7" } ] } }
    request = nil
    search = ->(**arguments) { request = arguments; response }

    with_stubbed_method(OPENSEARCH_CLIENT, :search, search) do
      ids = JobSearchService.new(query: "junior lahore onsite", location: "Lahore", job_type: "onsite",
                                 experience_level: "junior").job_ids
      assert_equal [ 42, 7 ], ids
    end

    assert_equal Rails.configuration.x.opensearch_index, request[:index]
    assert_equal 1000, request[:body][:size]
    assert_equal false, request[:body][:_source]
    query = request[:body][:query][:bool]
    assert_equal %w[junior lahore onsite], query[:must].map { |clause| clause[:multi_match][:query] }
    query[:must].each do |clause|
      assert_equal %w[title^3 company_name location job_type experience_level skills],
                   clause[:multi_match][:fields]
    end
    assert_equal [
      { term: { status: "active" } },
      { term: { "location.keyword" => "Lahore" } },
      { term: { job_type: "onsite" } },
      { term: { experience_level: "junior" } }
    ], query[:filter]
  end
end
