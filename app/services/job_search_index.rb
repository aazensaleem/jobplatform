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
