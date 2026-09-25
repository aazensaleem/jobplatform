require "test_helper"

class ApplicationTest < ActiveSupport::TestCase
  test "an application needs a candidate and job" do
    job = companies(:one).jobs.create!(title: "Open role", description: "Details", status: "active")

    without_user = Application.new(job: job)
    assert_not without_user.valid?
    assert_includes without_user.errors[:user], "must exist"

    without_job = Application.new(user: users(:one))
    assert_not without_job.valid?
    assert_includes without_job.errors[:job], "must exist"
  end

  test "a candidate cannot apply to the same job twice" do
    job = companies(:one).jobs.create!(title: "Open role", description: "Details", status: "active")
    candidate = users(:one)
    candidate.applications.create!(job: job)

    duplicate = candidate.applications.build(job: job)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:job_id], "has already been taken"
  end
end
