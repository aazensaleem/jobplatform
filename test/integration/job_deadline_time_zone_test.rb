require "test_helper"

class JobDeadlineTimeZoneTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "job deadline input and display use Pakistan time" do
    sign_in users(:two)
    job = jobs(:one)

    patch job_path(job), params: { job: { deadline: "2026-10-01T10:57" } }
    assert_redirected_to job_path(job)
    assert_equal Time.utc(2026, 10, 1, 5, 57), job.reload.deadline.utc

    get job_path(job)
    assert_select "dt", text: "Deadline (PKT)"
    assert_select "dd", text: /October 01, 2026 10:57/

    get edit_job_path(job)
    assert_select "label[for=job_deadline]", text: "Deadline (Pakistan time)"
    assert_select "input[name='job[deadline]'][value^='2026-10-01T10:57']"
  end
end
