class DailyJobAlertsJob < ApplicationJob
  queue_as :default

  def perform
    alerted_users = 0

    User.where(role: "candidate", job_alerts_enabled: true).find_each do |user|
      user.with_lock do
        next unless user.candidate? && user.job_alerts_enabled?

        cutoff = Time.current
        jobs = matching_jobs(user, cutoff)
        count = jobs.count
        if count.positive?
          titles = jobs.order(:id).limit(5).pluck(:title)
          remainder = count > titles.size ? " and #{count - titles.size} more" : ""
          user.notifications.create!(kind: "job_alert", message: "#{count} matching jobs: #{titles.join(', ')}#{remainder}.")
          alerted_users += 1
        end
        user.update!(last_job_alerted_at: cutoff)
      end
    end

    Rails.logger.info("Daily job alerts created for #{alerted_users} candidates")
    alerted_users
  end

  private

  def matching_jobs(user, cutoff)
    jobs = Job.where(status: "active").where("deadline IS NULL OR deadline > ?", cutoff)
              .where("created_at <= ?", cutoff)
    jobs = jobs.where("created_at > ?", user.last_job_alerted_at) if user.last_job_alerted_at
    jobs = jobs.where(location: user.alert_location) if user.alert_location.present?
    jobs = jobs.where(job_type: user.alert_job_type) if user.alert_job_type.present?
    jobs = jobs.where(experience_level: user.alert_experience_level) if user.alert_experience_level.present?
    jobs
  end
end
