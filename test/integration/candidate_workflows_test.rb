require "test_helper"

class CandidateWorkflowsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @candidate = users(:one)
    @job = companies(:one).jobs.create!(title: "Available role", description: "Description", status: "active", deadline: 1.day.from_now)
    @other_candidate = User.create!(email: "second-candidate@example.com", password: "password123")
  end

  test "candidate applies once with server assigned ownership and pending status" do
    sign_in @candidate
    get job_path(@job)
    assert_select "a[href=?]", new_job_application_path(@job)
    get new_job_application_path(@job)
    assert_response :success
    assert_difference "Application.count", 1 do
      post job_applications_path(@job), params: { application: { cover_letter: "My experience", user_id: @other_candidate.id, job_id: jobs(:two).id, status: "accepted" } }
    end
    assert_redirected_to my_applications_path
    application = @candidate.applications.find_by!(job: @job)
    assert_equal "pending", application.status
    assert_equal "My experience", application.cover_letter
    follow_redirect!
    assert_select "td", text: "Pending"
    get job_path(@job)
    assert_select "a[href=?]", new_job_application_path(@job), count: 0
    assert_no_difference "Application.count" do
      post job_applications_path(@job), params: { application: { cover_letter: "Again" } }
    end
    assert_response :unprocessable_entity
    assert_equal "My experience", application.reload.cover_letter
  end

  test "closed expired draft and past deadline jobs reject applications on submission" do
    sign_in @candidate
    [ [ "closed", nil ], [ "expired", nil ], [ "draft", nil ], [ "active", 1.second.ago ] ].each do |status, deadline|
      @job.update!(status: status, deadline: deadline)
      get job_path(@job)
      assert_select "a[href=?]", new_job_application_path(@job), count: 0
      assert_no_difference "Application.count" do
        post job_applications_path(@job), params: { application: { cover_letter: "Hello" } }
      end
      assert_response :unprocessable_entity
      assert_select "li", text: "Job is not accepting applications"
    end
    @job.update!(status: "active", deadline: nil)
    post job_applications_path(@job), params: { application: { cover_letter: "" } }
    assert_redirected_to my_applications_path
  end

  test "employer reviews own applicants and updates only status even after job closes" do
    application = @candidate.applications.create!(job: @job, cover_letter: "Candidate details")
    sign_in users(:two)
    get employer_job_applications_path(@job)
    assert_response :success
    assert_select "h2", text: @candidate.email
    assert_select "p", text: "Candidate details"
    @job.update!(status: "closed")
    Application::STATUSES.each do |status|
      patch employer_application_path(application), params: { application: { status: status, user_id: users(:two).id, job_id: jobs(:two).id, cover_letter: "Changed" } }
      assert_redirected_to employer_job_applications_path(@job)
      assert_equal status, application.reload.status
      assert_equal @candidate, application.user
      assert_equal @job, application.job
      assert_equal "Candidate details", application.cover_letter
    end
    patch employer_application_path(application), params: { application: { status: "invalid" } }
    assert_response :unprocessable_entity
    assert_select "li", text: "Status is not included in the list"
    assert_equal "accepted", application.reload.status
    sign_out users(:two)
    sign_in @candidate
    get my_applications_path
    assert_select "td", text: "Accepted"
  end

  test "application lists and updates respect ownership" do
    application = @candidate.applications.create!(job: @job)
    sign_in @other_candidate
    get my_applications_path
    assert_response :success
    assert_select "a[href=?]", job_path(@job), count: 0
    get employer_job_applications_path(@job)
    assert_response :forbidden
    patch employer_application_path(application), params: { application: { status: "accepted" } }
    assert_response :forbidden
    sign_out @other_candidate
    sign_in users(:other_employer)
    get employer_job_applications_path(@job)
    assert_response :forbidden
    patch employer_application_path(application), params: { application: { status: "accepted" } }
    assert_response :forbidden
    assert_equal "pending", application.reload.status
  end

  test "candidate saves once sees only own bookmarks and can unsave from either page" do
    sign_in @candidate
    assert_difference "SavedJob.count", 1 do
      post job_saved_jobs_path(@job), params: { saved_job: { user_id: @other_candidate.id, job_id: jobs(:two).id } }
    end
    assert_redirected_to job_path(@job)
    saved_job = @candidate.saved_jobs.find_by!(job: @job)
    assert_no_difference "SavedJob.count" do
      post job_saved_jobs_path(@job)
    end
    assert_redirected_to job_path(@job)
    @job.update!(status: "closed")
    get my_saved_jobs_path
    assert_select "a[href=?]", job_path(@job)
    assert_select "td", text: "Closed"
    get job_path(@job)
    assert_select "form[action=?]", my_saved_job_path(saved_job)
    assert_select "form[action=?]", job_saved_jobs_path(@job), count: 0
    sign_out @candidate
    sign_in @other_candidate
    get my_saved_jobs_path
    assert_select "a[href=?]", job_path(@job), count: 0
    assert_no_difference "SavedJob.count" do
      delete my_saved_job_path(saved_job)
    end
    assert_response :forbidden
    sign_out @other_candidate
    sign_in @candidate
    assert_difference "SavedJob.count", -1 do
      delete my_saved_job_path(saved_job)
    end
    assert_redirected_to my_saved_jobs_path
    post job_saved_jobs_path(@job)
    assert_redirected_to job_path(@job)
  end

  test "anonymous and employer requests cannot apply or save" do
    get my_applications_path
    assert_redirected_to new_user_session_path
    get my_saved_jobs_path
    assert_redirected_to new_user_session_path
    post job_applications_path(@job), params: { application: { cover_letter: "Hello" } }
    assert_redirected_to new_user_session_path
    post job_saved_jobs_path(@job)
    assert_redirected_to new_user_session_path
    get employer_job_applications_path(@job)
    assert_redirected_to new_user_session_path
    sign_in users(:two)
    assert_no_difference [ "Application.count", "SavedJob.count" ] do
      post job_applications_path(@job), params: { application: { cover_letter: "Hello" } }
      assert_response :forbidden
      post job_saved_jobs_path(@job)
      assert_response :forbidden
    end
    get my_applications_path
    assert_response :forbidden
    get my_saved_jobs_path
    assert_response :forbidden
  end

  test "admin may review but cannot apply as a noncandidate" do
    application = @candidate.applications.create!(job: @job)
    sign_in users(:admin)
    get employer_job_applications_path(@job)
    assert_response :success
    patch employer_application_path(application), params: { application: { status: "shortlisted" } }
    assert_redirected_to employer_job_applications_path(@job)
    assert_no_difference "Application.count" do
      post job_applications_path(@job), params: { application: { cover_letter: "Hello" } }
    end
    assert_response :unprocessable_entity
  end

  test "empty pages render useful messages" do
    sign_in @other_candidate
    get my_applications_path
    assert_select "p", text: "You have not applied for any jobs yet."
    get my_saved_jobs_path
    assert_select "p", text: "You have not saved any jobs yet."
    sign_out @other_candidate
    sign_in users(:two)
    get employer_job_applications_path(@job)
    assert_select "p", text: "No applications for this job yet."
  end

  test "submission rechecks a job closed after the application form was opened" do
    sign_in @candidate
    get new_job_application_path(@job)
    assert_select "input[type=submit]"
    @job.update!(status: "closed")
    assert_no_difference "Application.count" do
      post job_applications_path(@job), params: { application: { cover_letter: "Hello" } }
    end
    assert_response :unprocessable_entity
  end

  test "database unique indexes reject duplicates even without model validations" do
    @candidate.applications.create!(job: @job)
    @candidate.saved_jobs.create!(job: @job)
    assert_raises ActiveRecord::RecordNotUnique do
      @candidate.applications.build(job: @job).save!(validate: false)
    end
    assert_raises ActiveRecord::RecordNotUnique do
      @candidate.saved_jobs.build(job: @job).save!(validate: false)
    end
  end
end
