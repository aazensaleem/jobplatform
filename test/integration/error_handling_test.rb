require "test_helper"

class ErrorHandlingTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "missing records return a predictable 404" do
    get job_path(999_999)
    assert_response :not_found
    assert_equal "Not found", response.body

    get company_path(999_999)
    assert_response :not_found
    assert_equal "Not found", response.body
  end

  test "a Redis enqueue failure does not turn a saved job into a request error" do
    previous_sync = Rails.configuration.x.opensearch_sync
    Rails.configuration.x.opensearch_sync = true
    sign_in users(:two)
    enqueue_failure = ->(*) { raise RedisClient::ConnectionError, "Redis unavailable" }

    with_stubbed_method(IndexJobInOpenSearchJob, :perform_later, enqueue_failure) do
      assert_difference "Job.count", 1 do
        post jobs_path, params: { job: { title: "Resilient role", description: "Details",
                                         company_id: companies(:one).id, status: "active" } }
      end
    end

    assert_response :redirect
    assert Job.exists?(title: "Resilient role")
  ensure
    Rails.configuration.x.opensearch_sync = previous_sync
  end
end
