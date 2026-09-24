require "test_helper"

class JobSearchSyncTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @previous_sync = Rails.configuration.x.opensearch_sync
    Rails.configuration.x.opensearch_sync = true
    clear_enqueued_jobs
  end

  teardown do
    Rails.configuration.x.opensearch_sync = @previous_sync
    clear_enqueued_jobs
  end

  test "committed job changes enqueue IDs without calling OpenSearch" do
    with_stubbed_method(JobSearchIndex, :index, ->(*) { raise "OpenSearch called during save" }) do
      with_stubbed_method(JobSearchIndex, :delete, ->(*) { raise "OpenSearch called during destroy" }) do
        job = Job.create!(company: companies(:one), title: "New role", description: "Details", status: "active")
        assert_enqueued_with(job: IndexJobInOpenSearchJob, args: [ job.id ])

        job.update!(title: "Updated role")
        assert_equal 2, enqueued_jobs.count { |entry| entry[:job] == IndexJobInOpenSearchJob }

        job.destroy!
        assert_enqueued_with(job: DeleteJobFromOpenSearchJob, args: [ job.id ])
      end
    end
  end

  test "renaming a company enqueues its jobs for indexing" do
    companies(:one).update!(name: "Renamed company")

    assert_enqueued_with(job: IndexJobInOpenSearchJob, args: [ jobs(:one).id ])
    assert_equal 1, enqueued_jobs.size
  end

  test "a failed enqueue does not undo the committed job" do
    enqueue_failure = ->(*) { raise RedisClient::ConnectionError, "Redis unavailable" }

    with_stubbed_method(IndexJobInOpenSearchJob, :perform_later, enqueue_failure) do
      job = Job.create!(company: companies(:one), title: "Saved role", description: "Details")
      assert job.persisted?
      assert Job.exists?(job.id)
    end
  end
end
