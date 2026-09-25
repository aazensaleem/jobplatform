class DeleteJobFromOpenSearchJob < ApplicationJob
  queue_as :default

  def perform(job_id)
    JobSearchIndex.delete(job_id)
    Rails.logger.info("OpenSearch deletion succeeded for job_id=#{job_id}")
  rescue StandardError => error
    Rails.logger.error("OpenSearch deletion failed for job_id=#{job_id}: #{error.class}: #{error.message}")
    raise
  end
end
