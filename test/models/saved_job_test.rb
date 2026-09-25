require "test_helper"

class SavedJobTest < ActiveSupport::TestCase
  test "a candidate cannot save the same job twice" do
    candidate = users(:one)
    job = jobs(:one)

    duplicate = candidate.saved_jobs.build(job: job)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:job_id], "has already been taken"
  end
end
