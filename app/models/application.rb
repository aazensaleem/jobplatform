class Application < ApplicationRecord
  STATUSES = %w[pending shortlisted rejected accepted].freeze

  belongs_to :user
  belongs_to :job

  validates :status, inclusion: { in: STATUSES }
  validates :job_id, uniqueness: { scope: :user_id }
  validate :candidate_and_open_job, on: :create

  private

  def candidate_and_open_job
    errors.add(:user, "must be a candidate") unless user&.candidate?
    errors.add(:job, "is not accepting applications") unless job&.accepting_applications?
  end
end
