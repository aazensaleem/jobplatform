require "test_helper"

class JobAlertPreferencesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "candidate can enable alerts with trimmed filters and later disable them" do
    candidate = users(:one)
    sign_in candidate
    get my_job_alerts_path
    assert_response :success
    assert_select "h1", text: "Job alerts"

    patch my_job_alerts_path, params: { user: { job_alerts_enabled: "1", alert_location: "  Lahore  ", alert_job_type: "", alert_experience_level: " Junior " } }
    assert_redirected_to my_job_alerts_path
    assert candidate.reload.job_alerts_enabled?
    assert_equal "Lahore", candidate.alert_location
    assert_nil candidate.alert_job_type
    assert_equal "Junior", candidate.alert_experience_level

    candidate.update!(last_job_alerted_at: Time.current)
    patch my_job_alerts_path, params: { user: { job_alerts_enabled: "0", alert_location: "Lahore", alert_job_type: "", alert_experience_level: "Junior" } }
    assert_redirected_to my_job_alerts_path
    assert_not candidate.reload.job_alerts_enabled?
    assert_nil candidate.last_job_alerted_at
  end

  test "enabled alerts require at least one filter" do
    candidate = users(:one)
    sign_in candidate
    patch my_job_alerts_path, params: { user: { job_alerts_enabled: "1", alert_location: " ", alert_job_type: "", alert_experience_level: "" } }
    assert_response :unprocessable_entity
    assert_select "li", text: "Choose at least one job alert filter."
    assert_not candidate.reload.job_alerts_enabled?
  end

  test "only candidates can edit alert preferences" do
    get my_job_alerts_path
    assert_redirected_to new_user_session_path
    sign_in users(:two)
    get my_job_alerts_path
    assert_response :forbidden
    patch my_job_alerts_path, params: { user: { job_alerts_enabled: "1", alert_location: "Lahore" } }
    assert_response :forbidden
    assert_not users(:two).reload.job_alerts_enabled?
  end
end
