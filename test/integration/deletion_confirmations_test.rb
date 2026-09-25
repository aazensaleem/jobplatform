require "test_helper"

class DeletionConfirmationsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "employer delete controls request confirmation on every listing" do
    sign_in users(:two)
    company = companies(:one)
    job = jobs(:one)

    get companies_path
    assert_select "script[src*='confirmations']"
    assert_select "form[action=?] button[data-confirm=?]", company_path(company),
                  "Delete this company and all its jobs?"

    get company_path(company)
    assert_select "form[action=?] button[data-confirm=?]", company_path(company),
                  "Delete this company and all its jobs?"

    get jobs_path
    assert_select "form[action=?] button[data-confirm=?]", job_path(job), "Delete this job?"

    get job_path(job)
    assert_select "form[action=?] button[data-confirm=?]", job_path(job), "Delete this job?"

    get employer_jobs_path
    assert_select "form[action=?] button[data-confirm=?]", job_path(job), "Delete this job?"
  end

  test "candidate unsave controls request confirmation" do
    sign_in users(:one)
    saved_job = saved_jobs(:one)
    message = "Remove this job from your saved jobs?"

    get my_saved_jobs_path
    assert_select "form[action=?] button[data-confirm=?]", my_saved_job_path(saved_job), message

    get job_path(saved_job.job)
    assert_select "form[action=?] button[data-confirm=?]", my_saved_job_path(saved_job), message

    get edit_user_registration_path
    assert_select "form[action=?] button[data-confirm]", user_registration_path
  end
end
