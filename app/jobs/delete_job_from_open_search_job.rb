class DeleteJobFromOpenSearchJob < ApplicationJob
  queue_as :default

  def perform(job_id)
    JobSearchIndex.delete(job_id)
  end
end
