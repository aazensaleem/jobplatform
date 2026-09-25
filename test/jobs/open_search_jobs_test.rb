require "test_helper"

class OpenSearchJobsTest < ActiveSupport::TestCase
  test "index worker loads the latest job state from MySQL" do
    job = jobs(:one)
    job.update!(title: "Latest title")
    indexed = nil

    with_stubbed_method(JobSearchIndex, :index, ->(record) { indexed = record.search_document }) do
      IndexJobInOpenSearchJob.perform_now(job.id)
    end

    assert_equal "Latest title", indexed[:title]
    assert_equal companies(:one).name, indexed[:company_name]
  end

  test "index worker removes a document if the job was deleted before execution" do
    removed_id = nil
    job_id = jobs(:one).id
    jobs(:one).destroy!

    with_stubbed_method(JobSearchIndex, :delete, ->(id) { removed_id = id }) do
      IndexJobInOpenSearchJob.perform_now(job_id)
    end

    assert_equal job_id, removed_id
  end

  test "delete worker removes the document by ID" do
    removed_id = nil
    job_id = jobs(:one).id

    with_stubbed_method(JobSearchIndex, :delete, ->(id) { removed_id = id }) do
      DeleteJobFromOpenSearchJob.perform_now(job_id)
    end

    assert_equal job_id, removed_id
  end

  test "indexing failures propagate so Sidekiq can retry" do
    with_stubbed_method(JobSearchIndex, :index, ->(*) { raise IOError, "OpenSearch unavailable" }) do
      assert_raises(IOError) { IndexJobInOpenSearchJob.perform_now(jobs(:one).id) }
    end
  end

  test "deletion failures propagate so Sidekiq can retry" do
    with_stubbed_method(JobSearchIndex, :delete, ->(*) { raise IOError, "OpenSearch unavailable" }) do
      assert_raises(IOError) { DeleteJobFromOpenSearchJob.perform_now(jobs(:one).id) }
    end
  end
end
