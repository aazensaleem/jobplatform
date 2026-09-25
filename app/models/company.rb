class Company < ApplicationRecord
  belongs_to :user
  has_many :jobs, dependent: :destroy

  validates :name, presence: true

  after_update_commit :sync_jobs_for_search, if: :saved_change_to_name?

  private

  def sync_jobs_for_search
    return unless Rails.configuration.x.opensearch_sync

    jobs.find_each do |job|
      queued_job = IndexJobInOpenSearchJob.perform_later(job.id)
      Rails.logger.info("OpenSearch indexing queued for job_id=#{job.id} after company_id=#{id} rename") if queued_job
    end
  rescue StandardError => error
    Rails.logger.error("Could not enqueue OpenSearch indexing for company #{id}: #{error.class}: #{error.message}")
  end
end
