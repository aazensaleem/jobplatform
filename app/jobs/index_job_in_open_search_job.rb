class IndexJobInOpenSearchJob < ApplicationJob
  queue_as :default

  def perform(job_id)
    job = Job.includes(:company).find_by(id: job_id)

    if job
      JobSearchIndex.index(job)
    else
      JobSearchIndex.delete(job_id)
    end
  end
end
