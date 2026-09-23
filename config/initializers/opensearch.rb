# Constructing the client does not contact the server. Existing MySQL-backed
# pages and tests can run while OpenSearch is stopped.
OPENSEARCH_CLIENT = OpenSearch::Client.new(
  url: ENV.fetch("OPENSEARCH_URL", "http://127.0.0.1:9200"),
  transport_options: { request: { timeout: 5, open_timeout: 2 } },
  retry_on_failure: false
)

Rails.application.config.x.opensearch_index = ENV.fetch(
  "OPENSEARCH_INDEX", "jobplatform_jobs_#{Rails.env}"
)

# Tests opt into callback synchronization when verifying it with a stub client.
Rails.application.config.x.opensearch_sync = !Rails.env.test?
