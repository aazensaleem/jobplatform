require "test_helper"

class AdminNamespaceTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "admin pages require login and reject other roles" do
    pages = [ admin_root_path, admin_users_path, admin_user_path(users(:one)),
              admin_companies_path, admin_company_path(companies(:one)),
              admin_jobs_path, admin_applications_path,
              admin_application_path(applications(:one)) ]

    pages.each do |path|
      get path
      assert_redirected_to new_user_session_path
    end

    [ users(:one), users(:two) ].each do |user|
      sign_in user
      pages.each do |path|
        get path
        assert_response :forbidden
      end
      patch close_admin_job_path(jobs(:one))
      assert_response :forbidden
      delete admin_job_path(jobs(:one))
      assert_response :forbidden
      delete admin_company_path(companies(:one))
      assert_response :forbidden
      delete admin_user_path(users(:admin))
      assert_response :forbidden
      sign_out user
    end
    assert Job.exists?(jobs(:one).id)
    assert Company.exists?(companies(:one).id)
    assert User.exists?(users(:admin).id)
  end

  test "admin can browse the four sections and inspect related records" do
    sign_in users(:admin)

    get admin_root_path
    assert_response :success
    assert_select "a[href=?]", admin_users_path
    assert_select "a[href=?]", admin_companies_path
    assert_select "a[href=?]", admin_jobs_path
    assert_select "a[href=?]", admin_applications_path
    assert_select "a[href=?]", admin_user_path(users(:one))

    get admin_companies_path
    assert_select "a[href=?]", admin_company_path(companies(:one))
    assert_select "a[href=?]", admin_user_path(users(:two))
    assert_select "form[action=?] button[data-confirm]", admin_company_path(companies(:one))
    get admin_company_path(companies(:one))
    assert_select "a[href=?]", job_path(jobs(:one))
    assert_select "form[action=?] button[data-confirm]", admin_company_path(companies(:one))

    get admin_jobs_path
    assert_select "form[action=?]", close_admin_job_path(jobs(:one))
    assert_select "form[action=?] button[data-confirm]", admin_job_path(jobs(:one))

    get admin_applications_path
    assert_select "a[href=?]", admin_application_path(applications(:one))
    assert_select "td", text: "Pending"
    get admin_application_path(applications(:one))
    assert_select "dd", text: "Pending"
    assert_select "dd", text: "MyText"
  end

  test "user filters combine role and email and escape like wildcards" do
    sign_in users(:admin)
    get admin_users_path, params: { role: "employer", email: "other-" }
    assert_response :success
    assert_select "a[href=?]", admin_user_path(users(:other_employer))
    assert_select "a[href=?]", admin_user_path(users(:two)), count: 0
    assert_select "a[href=?]", admin_user_path(users(:one)), count: 0

    get admin_users_path, params: { email: "%" }
    assert_select "p", text: "No users match these filters."
    get admin_users_path, params: { role: "unknown" }
    assert_select "p", text: "No users match these filters."
  end

  test "admin can close and delete jobs from the admin area" do
    sign_in users(:admin)
    job = jobs(:one)

    patch close_admin_job_path(job), params: { job: { company_id: companies(:two).id } }
    assert_redirected_to admin_jobs_path
    assert_equal "closed", job.reload.status
    assert_equal companies(:one), job.company
    patch close_admin_job_path(job)
    assert_redirected_to admin_jobs_path

    assert_difference [ "Job.count", "Application.count" ], -1 do
      delete admin_job_path(job)
    end
    assert_redirected_to admin_jobs_path
  end

  test "admin can delete one company without removing its employer or other companies" do
    employer = users(:two)
    kept_company = employer.companies.create!(name: "Keep Me")
    kept_job = kept_company.jobs.create!(title: "Kept role", description: "Description")
    removed_company = companies(:one)
    removed_job = jobs(:one)
    removed_application = applications(:one)
    sign_in users(:admin)

    get admin_user_path(employer)
    assert_select "a[href=?]", admin_company_path(removed_company)
    assert_select "a[href=?]", admin_company_path(kept_company)

    assert_difference [ "Company.count", "Job.count", "Application.count" ], -1 do
      delete admin_company_path(removed_company)
    end
    assert_redirected_to admin_companies_path
    assert User.exists?(employer.id)
    assert Company.exists?(kept_company.id)
    assert Job.exists?(kept_job.id)
    assert_not Company.exists?(removed_company.id)
    assert_not Job.exists?(removed_job.id)
    assert_not Application.exists?(removed_application.id)
  end

  test "removing an employer also removes all their companies" do
    employer = users(:two)
    second_company = employer.companies.create!(name: "Second company")
    second_job = second_company.jobs.create!(title: "Second role", description: "Description")
    sign_in users(:admin)

    assert_difference "Company.count", -2 do
      delete admin_user_path(employer)
    end
    assert_redirected_to admin_users_path
    assert_not Job.exists?(second_job.id)
  end

  test "admin can remove another user but cannot remove their own account" do
    sign_in users(:admin)
    get admin_user_path(users(:one))
    assert_select "form[action=?] button[data-confirm]", admin_user_path(users(:one))

    assert_no_difference "User.count" do
      delete admin_user_path(users(:admin))
    end
    assert_redirected_to admin_user_path(users(:admin))

    assert_difference [ "User.count", "Application.count" ], -1 do
      delete admin_user_path(users(:one))
    end
    assert_redirected_to admin_users_path
  end
end
