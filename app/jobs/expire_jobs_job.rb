class ExpireJobsJob < ApplicationJob
  queue_as :default

  def perform
    now = Time.current
    expired_count = 0

    Job.where(status: "active").where("deadline < ?", now).find_each do |job|
      job.with_lock do
        if job.status == "active" && job.deadline && job.deadline < now
          job.update!(status: "expired")
          expired_count += 1
        end
      end
    end

    Rails.logger.info("Expired #{expired_count} jobs")
    expired_count
  end
end
