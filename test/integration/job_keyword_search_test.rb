require "test_helper"

class JobKeywordSearchTest < ActionDispatch::IntegrationTest
  setup do
    @active = jobs(:one)
    @closed = jobs(:two)
    @closed.update!(status: "closed")
  end

  test "keyword search uses service results but only displays active MySQL jobs" do
    service = Struct.new(:job_ids).new([ @active.id, @closed.id, 999_999 ])
    with_stubbed_method(JobSearchService, :new, ->(**) { service }) do
      get jobs_path, params: { q: " rails ", location: "Lahore", job_type: "remote",
                               experience_level: "junior" }
    end

    assert_response :success
    assert_select "input[name=q][value=rails]"
    assert_select "tbody tr", count: 1
    assert_select "tbody a[href=?]", job_path(@active)
    assert_select "tbody a[href=?]", job_path(@closed), count: 0
  end

  test "status and company filters cannot expose a closed or unrelated search result" do
    service = Struct.new(:job_ids).new([ @active.id, @closed.id ])
    with_stubbed_method(JobSearchService, :new, ->(**) { service }) do
      get jobs_path, params: { q: "developer", status: "closed" }
      assert_response :success
      assert_select "tbody tr", count: 0

      get jobs_path, params: { q: "developer", company_id: @closed.company_id }
      assert_response :success
      assert_select "tbody tr", count: 0
    end
  end

  test "missing index shows a clear message" do
    unavailable = ->(**) { raise OpenSearch::Transport::Transport::Errors::NotFound }
    with_stubbed_method(OPENSEARCH_CLIENT, :search, unavailable) do
      get jobs_path, params: { q: "rails" }
    end

    assert_response :success
    assert_select "p", text: /Keyword search is unavailable/
    assert_select "tbody tr", count: 0
  end
end
