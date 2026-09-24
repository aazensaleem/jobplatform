require "test_helper"

class NotificationWorkflowsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @candidate = users(:one)
    @employer = users(:two)
    @job = companies(:one).jobs.create!(title: "Notification test role", description: "Details", status: "active")
  end

  test "a successful application creates one notification for each party" do
    sign_in @candidate

    assert_difference "Notification.count", 2 do
      post job_applications_path(@job), params: { application: { cover_letter: "Interested" } }
    end
    assert_redirected_to my_applications_path
    candidate_notice = @candidate.notifications.sole
    employer_notice = @employer.notifications.sole
    assert_equal "application_submitted", candidate_notice.kind
    assert_includes candidate_notice.message, @job.title
    assert_includes candidate_notice.message, companies(:one).name
    assert_equal "new_applicant", employer_notice.kind
    assert_includes employer_notice.message, @candidate.email
    assert_includes employer_notice.message, @job.title

    assert_no_difference "Notification.count" do
      post job_applications_path(@job), params: { application: { cover_letter: "Again" } }
    end
    assert_response :unprocessable_entity
  end

  test "a status notification is created only when the status changes" do
    application = @candidate.applications.create!(job: @job)
    sign_in @employer

    %w[shortlisted rejected accepted].each do |status|
      assert_difference "Notification.count", 1 do
        patch employer_application_path(application), params: { application: { status: status } }
      end
      assert_redirected_to employer_job_applications_path(@job)
    end
    assert_no_difference "Notification.count" do
      patch employer_application_path(application), params: { application: { status: "accepted" } }
      patch employer_application_path(application), params: { application: { status: "invalid" } }
    end
    assert_response :unprocessable_entity
    assert_equal %w[Shortlisted Rejected Accepted], @candidate.notifications.where(kind: "status_changed").order(:id).map { |notice| notice.message[/now (\w+)\./, 1] }
    assert_equal 1, @employer.notifications.count
  end

  test "users see and mark only their own notifications as read" do
    get my_notifications_path
    assert_redirected_to new_user_session_path

    @candidate.applications.create!(job: @job)
    candidate_notice = @candidate.notifications.sole
    employer_notice = @employer.notifications.sole
    sign_in @candidate
    get my_notifications_path
    assert_response :success
    assert_select "td", text: candidate_notice.message
    assert_select "td", text: employer_notice.message, count: 0
    assert_select "a[href=?]", my_notifications_path, text: "Notifications (1)"

    patch my_notification_path(employer_notice)
    assert_response :not_found
    assert_nil employer_notice.reload.read_at
    patch my_notification_path(candidate_notice)
    assert_redirected_to my_notifications_path
    assert candidate_notice.reload.read_at?
    get my_notifications_path
    assert_select "td", text: "Read"
    assert_select "a[href=?]", my_notifications_path, text: "Notifications (0)"

    sign_out @candidate
    sign_in @employer
    get my_notifications_path
    assert_select "td", text: employer_notice.message
    assert_select "td", text: candidate_notice.message, count: 0
  end

  test "new accounts see a useful empty state" do
    sign_in users(:other_employer)
    get my_notifications_path
    assert_response :success
    assert_select "p", text: "You have no notifications yet."
  end
end
