class JobSearchService
  MAX_RESULTS = 1000

  def initialize(query:, location: nil, job_type: nil, experience_level: nil)
    @query = query
    @location = location
    @job_type = job_type
    @experience_level = experience_level
  end

  def job_ids
    filters = [ { term: { status: "active" } } ]
    filters << { term: { "location.keyword" => @location } } if @location.present?
    filters << { term: { job_type: @job_type } } if @job_type.present?
    filters << { term: { experience_level: @experience_level } } if @experience_level.present?
    fields = %w[title^3 description company_name location skills experience_level]
    terms = @query.split.map { |term| { multi_match: { query: term, fields: fields } } }

    response = OPENSEARCH_CLIENT.search(
      index: Rails.configuration.x.opensearch_index,
      body: {
        size: MAX_RESULTS,
        _source: false,
        query: {
          bool: {
            must: terms,
            filter: filters
          }
        }
      }
    )
    response.fetch("hits").fetch("hits").map { |hit| Integer(hit.fetch("_id")) }
  end
end
