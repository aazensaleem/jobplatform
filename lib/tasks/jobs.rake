namespace :jobs do
  desc "Rebuild the OpenSearch jobs index from MySQL"
  task reindex: :environment do
    JobSearchIndex.reindex!
    puts "Reindexed #{Job.count} jobs in #{Rails.configuration.x.opensearch_index}."
  end
end
