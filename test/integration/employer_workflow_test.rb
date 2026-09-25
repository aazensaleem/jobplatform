require "test_helper"

class EmployerWorkflowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "dashboard requires login and rejects candidates" do
    get employer_jobs_path
    assert_redirected_to new_user_session_path

    sign_in users(:one)
    get employer_jobs_path
    assert_response :forbidden
  end

  test "dashboard shows only owned jobs including every status" do
    sign_in users(:two)
    Job::STATUSES.each do |status|
      companies(:one).jobs.create!(title: "Own #{status}", description: "Description", status: status)
    end

    get employer_jobs_path
    assert_response :success
    Job::STATUSES.each { |status| assert_select "td", text: "Own #{status}" }
    assert_select "a[href=?]", job_path(jobs(:two)), count: 0
    assert_select "a[href=?]", edit_company_path(companies(:one))
    assert_select "a[href=?]", edit_company_path(companies(:two)), count: 0
  end

  test "jobs page checkbox shows only the employers listings across owned companies" do
    get jobs_path
    assert_select "input[name=my_jobs][type=checkbox]", count: 0

    sign_in users(:one)
    get jobs_path, params: { my_jobs: "1" }
    assert_select "input[name=my_jobs][type=checkbox]", count: 0
    assert_select "tbody a[href=?]", job_path(jobs(:one))
    assert_select "tbody a[href=?]", job_path(jobs(:two))
    sign_out users(:one)

    employer = users(:two)
    second_company = employer.companies.create!(name: "Second employer company")
    second_job = second_company.jobs.create!(title: "Second owned role", description: "Description", status: "draft")
    sign_in employer

    get jobs_path
    assert_response :success
    assert_select "input[name=my_jobs][type=checkbox][data-submit-on-change]"
    assert_select "input[name=my_jobs][type=checkbox][checked]", count: 0
    assert_select "tbody a[href=?]", job_path(jobs(:two))

    get jobs_path, params: { my_jobs: "1" }
    assert_response :success
    assert_select "input[name=my_jobs][type=checkbox][checked]"
    assert_select "tbody a[href=?]", job_path(jobs(:one))
    assert_select "tbody a[href=?]", job_path(second_job)
    assert_select "tbody a[href=?]", job_path(jobs(:two)), count: 0

    get jobs_path, params: { my_jobs: "1", company_id: companies(:two).id }
    assert_response :success
    assert_select "tbody tr", count: 0

    get jobs_path, params: { my_jobs: "0" }
    assert_select "tbody a[href=?]", job_path(jobs(:two))
  end

  test "my listings checkbox also limits keyword results" do
    jobs(:two).update!(status: "active")
    sign_in users(:two)
    service = Struct.new(:job_ids).new([ jobs(:one).id, jobs(:two).id ])

    with_stubbed_method(JobSearchService, :new, ->(**) { service }) do
      get jobs_path, params: { q: "developer", my_jobs: "1" }
    end

    assert_response :success
    assert_select "input[name=q][value=developer]"
    assert_select "input[name=my_jobs][type=checkbox][checked]"
    assert_select "tbody a[href=?]", job_path(jobs(:one))
    assert_select "tbody a[href=?]", job_path(jobs(:two)), count: 0
  end

  test "employer without a company can complete setup and manage a listing" do
    employer = User.create!(email: "new-employer@example.com", password: "password123", role: "employer",
                            employer_approval_status: "approved")
    sign_in employer

    get employer_jobs_path
    assert_select "a[href=?]", new_company_path, text: "Create my company"
    get new_job_path
    assert_redirected_to new_company_path
    get new_company_path
    assert_response :success
    assert_select "select[name='company[user_id]']", count: 0

    assert_difference "Company.count", 1 do
      post companies_path, params: { company: { name: "New company", user_id: users(:other_employer).id } }
    end
    company = employer.reload.companies.first
    assert_equal employer, company.user
    assert_redirected_to company_path(company)
    follow_redirect!
    assert_response :success

    patch company_path(company), params: { company: { location: "Lahore" } }
    assert_equal "Lahore", company.reload.location
    get employer_jobs_path
    assert_select "p", text: "You have not posted any jobs yet."

    get new_job_path
    assert_select "option[selected][value=?]", company.id.to_s
    assert_difference "Job.count", 1 do
      post jobs_path, params: { job: { title: "New role", description: "Description", company_id: company.id, status: "draft" } }
    end
    job = company.jobs.last
    assert_redirected_to job_path(job)
    patch job_path(job), params: { job: { title: "Updated role", status: "active" } }
    assert_equal "Updated role", job.reload.title
    assert_equal "active", job.status

    patch close_job_path(job), params: { job: { title: "Ignored", company_id: companies(:two).id } }
    assert_redirected_to employer_jobs_path
    assert_equal "closed", job.reload.status
    assert_equal "Updated role", job.title
    assert_equal company, job.company
    follow_redirect!
    assert_select "form[action=?]", close_job_path(job), count: 0
    patch close_job_path(job)
    assert_redirected_to employer_jobs_path

    assert_difference "Job.count", -1 do
      delete job_path(job)
    end
    assert_redirected_to employer_jobs_path
  end

  test "invalid job submissions show errors and preserve owned company choices" do
    sign_in users(:two)
    assert_no_difference "Job.count" do
      post jobs_path, params: { job: { title: "", description: "Description", company_id: companies(:one).id } }
    end
    assert_response :unprocessable_entity
    assert_select "li", text: "Title can't be blank"
    assert_select "option[value=?]", companies(:two).id.to_s, count: 0

    patch job_path(jobs(:one)), params: { job: { title: "" } }
    assert_response :unprocessable_entity
    assert_not_equal "", jobs(:one).reload.title
  end

  test "employer cannot create close delete or take over another employers job" do
    sign_in users(:two)
    other_job = jobs(:two)
    original_attributes = other_job.attributes

    assert_no_difference "Job.count" do
      post jobs_path, params: { job: { title: "Unauthorized", description: "Description", company_id: companies(:two).id } }
      assert_response :forbidden
      delete job_path(other_job)
      assert_response :forbidden
    end
    patch close_job_path(other_job)
    assert_response :forbidden
    patch job_path(other_job), params: { job: { title: "Taken over", company_id: companies(:one).id } }
    assert_response :forbidden
    assert_equal original_attributes, other_job.reload.attributes

    patch company_path(companies(:two)), params: { company: { name: "Unauthorized" } }
    assert_response :forbidden
  end

  test "close requires login denies candidates and allows admins" do
    job = jobs(:one)
    patch close_job_path(job)
    assert_redirected_to new_user_session_path
    sign_in users(:one)
    patch close_job_path(job)
    assert_response :forbidden
    assert_equal "active", job.reload.status
    sign_out users(:one)
    sign_in users(:admin)
    patch close_job_path(job)
    assert_redirected_to job_path(job)
    assert_equal "closed", job.reload.status
  end
end
