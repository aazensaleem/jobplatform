class Job < ApplicationRecord
  STATUSES = %w[draft active closed expired].freeze

  belongs_to :company
  has_many :applications, dependent: :destroy
  has_many :saved_jobs, dependent: :destroy

  validates :title, :description, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :salary_min, :salary_max,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  def accepting_applications?
    status == "active" && (deadline.nil? || deadline > Time.current)
  end
end
