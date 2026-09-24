class Notification < ApplicationRecord
  KINDS = %w[application_submitted new_applicant status_changed].freeze

  belongs_to :user

  validates :kind, inclusion: { in: KINDS }
  validates :message, presence: true
end
