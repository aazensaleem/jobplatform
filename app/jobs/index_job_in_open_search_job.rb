class IndexJobInOpenSearchJob < ApplicationJob
  queue_as :default

  def perform(job_id)
    job = Job.includes(:company).find_by(id: job_id)

    if job
      JobSearchIndex.index(job)
      Rails.logger.info("OpenSearch indexing succeeded for job_id=#{job_id}")
    else
      JobSearchIndex.delete(job_id)
      Rails.logger.info("OpenSearch deletion succeeded for missing job_id=#{job_id}")
    end
  rescue StandardError => error
    Rails.logger.error("OpenSearch indexing failed for job_id=#{job_id}: #{error.class}: #{error.message}")
    raise
  end
end
