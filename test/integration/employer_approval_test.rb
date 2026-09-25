require "test_helper"

class EmployerApprovalTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "employer signup creates a pending account that can browse but cannot manage listings" do
    get new_employer_registration_path
    assert_response :success
    assert_select "form[action=?]", employer_registration_path

    assert_difference "User.count", 1 do
      post employer_registration_path, params: {
        user: { email: "pending@example.com", password: "password123",
                password_confirmation: "password123", role: "admin",
                employer_approval_status: "approved" }
      }
    end
    assert_redirected_to root_path
    employer = User.find_by!(email: "pending@example.com")
    assert employer.employer_pending?
    assert_nil employer.employer_decided_at

    get root_path
    assert_response :success
    assert_select "div[role=status]", text: /waiting for admin approval/
    assert_select "a[href=?]", new_employer_registration_path, count: 0
    get companies_path
    assert_select "a[href=?]", company_path(companies(:one))
    assert_select "a[href=?]", company_path(companies(:two))
    get jobs_path, params: { my_jobs: "1" }
    assert_select "input[name=my_jobs][type=checkbox]", count: 0
    assert_select "tbody a[href=?]", job_path(jobs(:one))
    assert_select "tbody a[href=?]", job_path(jobs(:two))

    get new_company_path
    assert_response :forbidden
    post companies_path, params: { company: { name: "Blocked" } }
    assert_response :forbidden
    get new_job_path
    assert_response :forbidden
    post jobs_path, params: { job: { title: "Blocked", description: "Description", company_id: companies(:one).id } }
    assert_response :forbidden
    get employer_jobs_path
    assert_response :forbidden
    get edit_user_registration_path
    assert_response :success
  end

  test "invalid employer signup keeps the employer form and creates no account" do
    assert_no_difference "User.count" do
      post employer_registration_path, params: {
        user: { email: "invalid@example.com", password: "password123",
                password_confirmation: "different" }
      }
    end

    assert_response :unprocessable_entity
    assert_select "form[action=?]", employer_registration_path
    assert_select "li", text: /Password confirmation/
  end

  test "candidate signup ignores approval fields and signed-in users cannot request another account" do
    assert_difference "User.count", 1 do
      post user_registration_path, params: {
        user: { email: "candidate-stays-candidate@example.com", password: "password123",
                password_confirmation: "password123", role: "employer",
                employer_approval_status: "approved" }
      }
    end
    candidate = User.find_by!(email: "candidate-stays-candidate@example.com")
    assert candidate.candidate?
    assert_nil candidate.employer_approval_status

    assert_no_difference "User.count" do
      post employer_registration_path, params: {
        user: { email: "second-account@example.com", password: "password123",
                password_confirmation: "password123" }
      }
    end
    assert_redirected_to root_path
  end

  test "pending employers cannot modify existing records even if assigned ownership" do
    employer = User.create!(email: "pending-owner@example.com", password: "password123", role: "employer")
    company = employer.companies.create!(name: "Pending company")
    job = company.jobs.create!(title: "Pending role", description: "Description", status: "active")
    sign_in employer

    get edit_company_path(company)
    assert_response :forbidden
    patch company_path(company), params: { company: { name: "Changed" } }
    assert_response :forbidden
    delete company_path(company)
    assert_response :forbidden
    get edit_job_path(job)
    assert_response :forbidden
    patch close_job_path(job)
    assert_response :forbidden
    delete job_path(job)
    assert_response :forbidden
    assert_no_difference "Job.count" do
      post jobs_path, params: { job: { title: "Blocked new job", description: "Description",
                                     company_id: company.id } }
    end
    assert_response :forbidden
    get employer_job_applications_path(job)
    assert_response :forbidden
    assert_equal "Pending company", company.reload.name
    assert_equal "active", job.reload.status
  end

  test "admin approval grants employer access and cannot be set through account update" do
    employer = User.create!(email: "review@example.com", password: "password123", role: "employer")
    sign_in employer
    patch user_registration_path, params: {
      user: { current_password: "password123", email: employer.email,
              role: "admin", employer_approval_status: "approved" }
    }
    assert_redirected_to root_path
    assert employer.reload.employer_pending?
    sign_out employer

    sign_in users(:admin)
    get admin_users_path, params: { role: "employer", approval_status: "pending" }
    assert_response :success
    assert_select "a[href=?]", admin_user_path(employer)
    assert_select "a[href=?]", admin_user_path(users(:two)), count: 0
    get admin_user_path(employer)
    assert_select "form[action=?]", approve_admin_user_path(employer)
    assert_select "form[action=?]", decline_admin_user_path(employer)
    patch approve_admin_user_path(employer)
    assert_redirected_to admin_user_path(employer)
    assert employer.reload.employer_approved?
    assert_not_nil employer.employer_decided_at
    sign_out users(:admin)

    sign_in employer
    get root_path
    assert_select "div[role=status]", text: /waiting for admin approval/, count: 0
    get new_company_path
    assert_response :success
    get jobs_path
    assert_select "input[name=my_jobs][type=checkbox]"
    assert_difference "Company.count", 1 do
      post companies_path, params: { company: { name: "Approved company" } }
    end
    company = Company.find_by!(name: "Approved company")
    assert_equal employer, company.user
    assert_difference "Job.count", 1 do
      post jobs_path, params: { job: { title: "Approved listing", description: "Description",
                                     status: "active", company_id: company.id } }
    end
    assert_equal company, Job.find_by!(title: "Approved listing").company
  end

  test "declined employers see a clear message remain signed in and can be reconsidered" do
    employer = User.create!(email: "declined@example.com", password: "password123", role: "employer")
    sign_in users(:admin)
    patch decline_admin_user_path(employer)
    assert_redirected_to admin_user_path(employer)
    assert employer.reload.employer_declined?
    assert_not_nil employer.employer_decided_at
    sign_out users(:admin)

    post user_session_path, params: { user: { email: employer.email, password: "password123" } }
    assert_redirected_to root_path
    get root_path
    assert_response :success
    assert_select "div[role=status]", text: /employer request was declined/
    assert_select "a[href=?]", edit_user_registration_path
    assert User.exists?(employer.id)
    get companies_path
    assert_select "a[href=?]", company_path(companies(:one))
    get new_company_path
    assert_response :forbidden
    sign_out employer

    sign_in users(:admin)
    get admin_users_path, params: { approval_status: "declined" }
    assert_select "a[href=?]", admin_user_path(employer)
    get admin_user_path(employer)
    assert_select "form[action=?]", approve_admin_user_path(employer)
    assert_select "form[action=?]", decline_admin_user_path(employer), count: 0
    patch approve_admin_user_path(employer)
    assert employer.reload.employer_approved?
    sign_out users(:admin)
    sign_in employer
    get new_company_path
    assert_response :success
  end

  test "only admins can decide and approved accounts cannot be declined as pending requests" do
    employer = User.create!(email: "decision@example.com", password: "password123", role: "employer")
    patch approve_admin_user_path(employer)
    assert_redirected_to new_user_session_path
    sign_in users(:one)
    patch approve_admin_user_path(employer)
    assert_response :forbidden
    patch decline_admin_user_path(employer)
    assert_response :forbidden
    sign_out users(:one)

    sign_in users(:admin)
    patch decline_admin_user_path(users(:one))
    assert_redirected_to admin_user_path(users(:one))
    patch approve_admin_user_path(employer)
    assert employer.reload.employer_approved?
    patch decline_admin_user_path(employer)
    assert_redirected_to admin_user_path(employer)
    assert employer.reload.employer_approved?
  end
end
