# Run with: bin/rails runner script/opensearch_check.rb
# Optionally select a job: JOB_ID=123 bin/rails runner script/opensearch_check.rb
job = ENV["JOB_ID"].present? ? Job.find(ENV.fetch("JOB_ID")) : Job.order(:id).first
abort "Create a job in the app first, then run this check again." unless job

client = OPENSEARCH_CLIENT
index = "#{Rails.configuration.x.opensearch_index}_check_#{SecureRandom.hex(8)}"
created = false

begin
  puts "OpenSearch version: #{client.info.fetch('version').fetch('number')}"
  definition = JSON.parse(Rails.root.join("config/opensearch/jobs.json").read)
  client.indices.create(index: index, body: definition)
  created = true
  client.index(index: index, id: job.id, body: job.search_document, refresh: true)

  response = client.search(index: index, body: {
    query: { multi_match: { query: job.title, fields: %w[title description company_name location skills] } }
  })
  hits = response.fetch("hits").fetch("hits")
  raise "The indexed job was not found in search results." unless hits.any? { |hit| hit.fetch("_id") == job.id.to_s }

  puts "Indexed and found MySQL job #{job.id}: #{job.title}"
ensure
  if created
    client.indices.delete(index: index)
    puts "Removed temporary check index: #{index}"
  end
end
