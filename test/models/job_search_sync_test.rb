require "test_helper"

class JobSearchSyncTest < ActiveSupport::TestCase
  setup do
    @previous_sync = Rails.configuration.x.opensearch_sync
    Rails.configuration.x.opensearch_sync = true
  end

  teardown do
    Rails.configuration.x.opensearch_sync = @previous_sync
  end

  test "committed job creates and updates sync while destruction removes the document" do
    synced = []
    removed = []
    with_stubbed_method(JobSearchIndex, :sync, ->(job) { synced << [ job.id, job.title ] }) do
      with_stubbed_method(JobSearchIndex, :remove, ->(id) { removed << id }) do
        job = Job.create!(company: companies(:one), title: "New role", description: "Details", status: "active")
        job.update!(title: "Updated role")
        job.destroy!
        assert_equal [ [ job.id, "New role" ], [ job.id, "Updated role" ] ], synced
        assert_equal [ job.id ], removed
      end
    end
  end

  test "renaming a company resyncs its jobs" do
    synced = []
    with_stubbed_method(JobSearchIndex, :sync, ->(job) { synced << job.id }) do
      companies(:one).update!(name: "Renamed company")
    end
    assert_equal [ jobs(:one).id ], synced
  end
end
