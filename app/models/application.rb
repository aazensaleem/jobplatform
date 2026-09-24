class Application < ApplicationRecord
  STATUSES = %w[pending shortlisted rejected accepted].freeze

  belongs_to :user
  belongs_to :job

  validates :status, inclusion: { in: STATUSES }
  validates :job_id, uniqueness: { scope: :user_id }
  validate :candidate_and_open_job, on: :create

  after_create :notify_application_submitted
  after_update :notify_status_changed, if: :saved_change_to_status?

  private

  def notify_application_submitted
    user.notifications.create!(kind: "application_submitted", message: "Your application for #{job.title} at #{job.company.name} was submitted.")
    job.company.user.notifications.create!(kind: "new_applicant", message: "#{user.email} applied for #{job.title}.")
  end

  def notify_status_changed
    user.notifications.create!(kind: "status_changed", message: "Your application for #{job.title} is now #{status.humanize}.")
  end

  def candidate_and_open_job
    errors.add(:user, "must be a candidate") unless user&.candidate?
    errors.add(:job, "is not accepting applications") unless job&.accepting_applications?
  end
end
