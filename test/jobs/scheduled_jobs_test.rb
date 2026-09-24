require "test_helper"

class ScheduledJobsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @previous_sync = Rails.configuration.x.opensearch_sync
    Rails.configuration.x.opensearch_sync = false
    clear_enqueued_jobs
  end

  teardown do
    Rails.configuration.x.opensearch_sync = @previous_sync
    clear_enqueued_jobs
  end

  test "hourly expiry changes only overdue active jobs and queues search updates" do
    travel_to Time.zone.local(2026, 9, 24, 12) do
      jobs(:one).update!(status: "closed")
      company = companies(:one)
      overdue = company.jobs.create!(title: "Overdue", description: "Details", status: "active", deadline: 1.minute.ago)
      future = company.jobs.create!(title: "Future", description: "Details", status: "active", deadline: 1.hour.from_now)
      closed = company.jobs.create!(title: "Closed", description: "Details", status: "closed", deadline: 1.day.ago)
      Rails.configuration.x.opensearch_sync = true

      assert_equal 1, ExpireJobsJob.perform_now
      assert_equal "expired", overdue.reload.status
      assert_equal "active", future.reload.status
      assert_equal "closed", closed.reload.status
      assert_enqueued_with(job: IndexJobInOpenSearchJob, args: [ overdue.id ])
      assert_equal 1, enqueued_jobs.count { |entry| entry[:job] == IndexJobInOpenSearchJob }
      assert_equal 0, ExpireJobsJob.perform_now
    end
  end

  test "daily alerts match all chosen filters once per new group of jobs" do
    candidate = users(:one)
    candidate.update!(job_alerts_enabled: true, alert_location: "Lahore", alert_job_type: "Full-time", alert_experience_level: "Junior")
    company = companies(:one)
    company.jobs.create!(title: "Matching role", description: "Details", status: "active", location: "Lahore", job_type: "Full-time", experience_level: "Junior")
    company.jobs.create!(title: "Other city", description: "Details", status: "active", location: "Karachi", job_type: "Full-time", experience_level: "Junior")
    company.jobs.create!(title: "Past deadline", description: "Details", status: "active", location: "Lahore", job_type: "Full-time", experience_level: "Junior", deadline: 1.hour.ago)

    assert_difference "candidate.notifications.count", 1 do
      assert_equal 1, DailyJobAlertsJob.perform_now
    end
    assert_includes candidate.notifications.last.message, "Matching role"
    assert_no_difference "candidate.notifications.count" do
      assert_equal 0, DailyJobAlertsJob.perform_now
    end

    company.jobs.create!(title: "New matching role", description: "Details", status: "active", location: "Lahore", job_type: "Full-time", experience_level: "Junior")
    assert_difference "candidate.notifications.count", 1 do
      assert_equal 1, DailyJobAlertsJob.perform_now
    end
    assert_includes candidate.notifications.last.message, "New matching role"
    assert_not_includes candidate.notifications.last.message, "Other city"
    assert_equal 0, users(:other_employer).notifications.where(kind: "job_alert").count
  end

  test "weekly statistics returns the requested counts" do
    baseline = WeeklyStatisticsJob.perform_now
    company = companies(:one)
    new_user = User.create!(email: "weekly-candidate@example.com", password: "password123")
    new_job = company.jobs.create!(title: "Weekly role", description: "Details", status: "active")
    new_user.applications.create!(job: new_job)

    result = WeeklyStatisticsJob.perform_now
    assert_equal baseline[:new_users] + 1, result[:new_users]
    assert_equal baseline[:new_jobs] + 1, result[:new_jobs]
    assert_equal baseline[:active_jobs] + 1, result[:active_jobs]
    assert_equal baseline[:expired_jobs], result[:expired_jobs]
    assert_equal baseline[:applications] + 1, result[:applications]
  end

  test "the three schedules name loadable jobs and valid cron times" do
    schedule = YAML.load_file(Rails.root.join("config/schedule.yml"))
    assert_equal %w[daily_job_alerts expire_jobs weekly_statistics], schedule.keys.sort
    schedule.each_value do |entry|
      assert Fugit::Cron.parse(entry.fetch("cron"))
      assert entry.fetch("class").constantize < ApplicationJob
      assert_equal true, entry.fetch("active_job")
      assert_equal "default", entry.fetch("queue")
    end
  end
end
