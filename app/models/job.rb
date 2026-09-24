class Job < ApplicationRecord
  STATUSES = %w[draft active closed expired].freeze

  belongs_to :company
  has_many :applications, dependent: :destroy
  has_many :saved_jobs, dependent: :destroy

  validates :title, :description, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :salary_min, :salary_max,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  after_commit :sync_search_index, on: %i[create update]
  after_commit :remove_from_search_index, on: :destroy

  def accepting_applications?
    status == "active" && (deadline.nil? || deadline > Time.current)
  end

  def search_document
    {
      id: id,
      title: title,
      description: description,
      company_name: company.name,
      location: location,
      job_type: job_type,
      experience_level: experience_level,
      # Skills are reserved in the search mapping; there is no MySQL skills field yet.
      skills: [],
      status: status
    }
  end

  private

  def sync_search_index
    IndexJobInOpenSearchJob.perform_later(id) if Rails.configuration.x.opensearch_sync
  rescue StandardError => error
    Rails.logger.error("Could not enqueue OpenSearch indexing for job #{id}: #{error.class}: #{error.message}")
  end

  def remove_from_search_index
    DeleteJobFromOpenSearchJob.perform_later(id) if Rails.configuration.x.opensearch_sync
  rescue StandardError => error
    Rails.logger.error("Could not enqueue OpenSearch deletion for job #{id}: #{error.class}: #{error.message}")
  end
end
