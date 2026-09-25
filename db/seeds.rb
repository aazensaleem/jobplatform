# Development-only demo data for search, pagination, grids, and scheduled jobs.
# Seed accounts use the reserved example.test domain and random passwords.
if Rails.env.development?
  Faker::Config.random = Random.new(21)
  previous_sync = Rails.configuration.x.opensearch_sync
  Rails.configuration.x.opensearch_sync = false

  begin
    candidates = 50.times.map do |index|
      User.find_or_create_by!(email: format("seed-candidate-%03d@example.test", index + 1)) do |user|
        user.role = "candidate"
        user.password = SecureRandom.base58(32)
      end
    end

    employers = 10.times.map do |index|
      User.find_or_create_by!(email: format("seed-employer-%02d@example.test", index + 1)) do |user|
        user.role = "employer"
        user.employer_approval_status = "approved"
        user.employer_decided_at = Time.current
        user.password = SecureRandom.base58(32)
      end
    end

    companies = employers.each_with_index.map do |employer, index|
      employer.companies.order(:id).first || employer.companies.create!(
        name: Faker::Company.name,
        description: Faker::Company.catch_phrase,
        location: %w[Karachi Lahore Islamabad Rawalpindi Faisalabad][index % 5]
      )
    end

    titles = [ "Software Engineer", "Rails Developer", "Product Designer", "Data Analyst",
               "QA Engineer", "DevOps Engineer", "Product Manager", "Frontend Developer",
               "Customer Success Specialist", "Marketing Analyst" ]
    locations = %w[Karachi Lahore Islamabad Rawalpindi Faisalabad Remote]
    job_types = %w[remote onsite hybrid]
    levels = %w[junior mid senior]

    jobs = 150.times.map do |index|
      company = companies[index % companies.length]
      company.jobs.find_or_create_by!(title: "#{titles[index % titles.length]} (Demo #{index + 1})") do |job|
        job.description = "#{Faker::Lorem.paragraph(sentence_count: 3)} Apply your skills to a growing team."
        job.location = locations[index % locations.length]
        job.job_type = job_types[index % job_types.length]
        job.experience_level = levels[(index / 3) % levels.length]
        job.salary_min = 60_000 + (index % 10) * 10_000
        job.salary_max = job.salary_min + 50_000
        job.status = case index
        when 0...120 then "active"
        when 120...135 then "draft"
        when 135...145 then "closed"
        else "expired"
        end
        job.deadline = job.status == "active" ? 1.year.from_now + index.days : nil
      end
    end

    active_jobs = jobs.first(120)
    200.times do |index|
      Application.find_or_create_by!(user: candidates[index % candidates.length],
                                     job: active_jobs[index % active_jobs.length]) do |application|
        application.status = Application::STATUSES[index % Application::STATUSES.length]
        application.cover_letter = Faker::Lorem.paragraph(sentence_count: 2)
      end
    end

    100.times do |index|
      SavedJob.find_or_create_by!(user: candidates[index % candidates.length],
                                 job: jobs[index % jobs.length])
    end
  ensure
    Rails.configuration.x.opensearch_sync = previous_sync
  end

  puts "Phase 21 demo data ready: #{candidates.length} candidates, #{employers.length} employers, " \
       "#{companies.length} companies, #{jobs.length} jobs, 200 applications, 100 saved jobs."
  puts "Run bin/rails jobs:reindex to refresh OpenSearch."
end
