class WeeklyStatisticsJob < ApplicationJob
  queue_as :default

  def perform
    since = 7.days.ago
    statistics = {
      new_users: User.where(created_at: since..).count,
      new_jobs: Job.where(created_at: since..).count,
      active_jobs: Job.where(status: "active").count,
      expired_jobs: Job.where(status: "expired").count,
      applications: Application.where(created_at: since..).count
    }

    Rails.logger.info("Weekly statistics (since #{since.iso8601}): #{statistics.inspect}")
    statistics
  end
end
