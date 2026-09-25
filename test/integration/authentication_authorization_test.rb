require "test_helper"

class AuthenticationAuthorizationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "anonymous visitors can browse but protected actions require login" do
    get jobs_path
    assert_response :success

    get companies_path
    assert_response :success

    get new_job_path
    assert_redirected_to new_user_session_path

    get new_company_path
    assert_redirected_to new_user_session_path
  end

  test "a visitor can register as a candidate and sign out" do
    assert_difference("User.count", 1) do
      post user_registration_path, params: {
        user: {
          email: "new-candidate@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to root_path
    assert_equal "candidate", User.find_by!(email: "new-candidate@example.com").role

    delete destroy_user_session_path
    assert_redirected_to root_path
  end

  test "a user can sign in change their password and sign out" do
    post user_session_path, params: {
      user: { email: users(:one).email, password: "password123" }
    }
    assert_redirected_to root_path

    get edit_user_registration_path
    assert_response :success

    patch user_registration_path, params: {
      user: {
        current_password: "password123",
        password: "new-password123",
        password_confirmation: "new-password123"
      }
    }
    assert_redirected_to root_path

    delete destroy_user_session_path
    assert_redirected_to root_path

    post user_session_path, params: {
      user: { email: users(:one).email, password: "new-password123" }
    }
    assert_redirected_to root_path

    delete destroy_user_session_path
    assert_redirected_to root_path

    get new_user_password_path
    assert_response :success
  end

  test "a candidate cannot manage jobs or companies" do
    sign_in users(:one)

    get new_job_path
    assert_response :forbidden

    get edit_job_path(jobs(:one))
    assert_response :forbidden

    get new_company_path
    assert_response :forbidden

    get edit_company_path(companies(:one))
    assert_response :forbidden
  end

  test "an employer manages only their own company and jobs" do
    sign_in users(:two)

    get new_job_path
    assert_response :success

    get edit_job_path(jobs(:one))
    assert_response :success

    get edit_job_path(jobs(:two))
    assert_response :forbidden

    get edit_company_path(companies(:one))
    assert_response :success

    get edit_company_path(companies(:two))
    assert_response :forbidden
  end

  test "the companies page lists only the signed-in employer's company" do
    sign_in users(:two)

    get companies_path
    assert_response :success
    assert_select "a[href=?]", company_path(companies(:one)), count: 1
    assert_select "a[href=?]", company_path(companies(:two)), count: 0
  end

  test "an employer without a company sees an empty companies page" do
    employer = User.create!(email: "no-company@example.com", password: "password123", role: "employer",
                            employer_approval_status: "approved")
    sign_in employer

    get companies_path
    assert_response :success
    assert_select "p", text: "You have not created a company yet."
    assert_select "a[href=?]", company_path(companies(:one)), count: 0
  end

  test "the public companies page still lists all companies" do
    get companies_path

    assert_response :success
    assert_select "a[href=?]", company_path(companies(:one)), count: 1
    assert_select "a[href=?]", company_path(companies(:two)), count: 1
  end

  test "an employer cannot move their job to another employer company" do
    sign_in users(:two)
    job = jobs(:one)

    patch job_path(job), params: {
      job: {
        title: job.title,
        description: job.description,
        company_id: companies(:two).id,
        status: job.status
      }
    }

    assert_response :forbidden
    assert_equal companies(:one), job.reload.company
  end

  test "an admin can manage all companies and jobs" do
    sign_in users(:admin)

    get edit_job_path(jobs(:one))
    assert_response :success

    get edit_job_path(jobs(:two))
    assert_response :success

    get edit_company_path(companies(:one))
    assert_response :success

    get edit_company_path(companies(:two))
    assert_response :success
  end
end
