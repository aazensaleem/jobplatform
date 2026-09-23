class SavedJob < ApplicationRecord
  belongs_to :user
  belongs_to :job

  validates :job_id, uniqueness: { scope: :user_id }
  validate :candidate_owner, on: :create

  private

  def candidate_owner
    errors.add(:user, "must be a candidate") unless user&.candidate?
  end
end
