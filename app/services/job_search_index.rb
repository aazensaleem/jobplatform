class JobSearchIndex
  class << self
    def index(job)
      ensure_index!
      OPENSEARCH_CLIENT.index(index: index_name, id: job.id, body: job.search_document)
    end

    def delete(job_id)
      return unless OPENSEARCH_CLIENT.indices.exists?(index: index_name)

      OPENSEARCH_CLIENT.delete(index: index_name, id: job_id)
    rescue OpenSearch::Transport::Transport::Errors::NotFound
      nil
    end

    def reindex!
      OPENSEARCH_CLIENT.indices.delete(index: index_name) if OPENSEARCH_CLIENT.indices.exists?(index: index_name)
      OPENSEARCH_CLIENT.indices.create(index: index_name, body: index_definition)
      Job.includes(:company).find_each do |job|
        OPENSEARCH_CLIENT.index(index: index_name, id: job.id, body: job.search_document)
      end
      OPENSEARCH_CLIENT.indices.refresh(index: index_name)
    end

    def sync(job)
      index(job)
    rescue StandardError => error
      Rails.logger.error("OpenSearch job sync failed for job #{job.id}: #{error.class}: #{error.message}")
    end

    def remove(job_id)
      delete(job_id)
    rescue StandardError => error
      Rails.logger.error("OpenSearch job deletion failed for job #{job_id}: #{error.class}: #{error.message}")
    end

    private

    def ensure_index!
      return if OPENSEARCH_CLIENT.indices.exists?(index: index_name)

      OPENSEARCH_CLIENT.indices.create(index: index_name, body: index_definition)
    rescue OpenSearch::Transport::Transport::Errors::BadRequest
      raise unless OPENSEARCH_CLIENT.indices.exists?(index: index_name)
    end

    def index_definition
      JSON.parse(Rails.root.join("config/opensearch/jobs.json").read)
    end

    def index_name
      Rails.configuration.x.opensearch_index
    end
  end
end
