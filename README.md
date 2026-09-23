# Job Marketplace

A Ruby on Rails application where employers post jobs and candidates apply for
roles and save listings.

## Features

- User registration and login with Devise
- Role-based permissions with CanCanCan
- Company and job management
- Filter jobs by location, job type, experience level, status, and company
- Search active jobs by keyword through OpenSearch, with location, job type, and experience filters
- Automatic OpenSearch synchronization for job changes and company renames
- Redis and Sidekiq background job processing, with a console check job
- Employer dashboard and applicant status updates
- Candidate applications and saved jobs

## Requirements

- Ruby 4.0.7
- Rails 8.1.3.1 (installed through Bundler)
- MySQL 8.2
- Redis 8.10.1 for Sidekiq jobs

## Setup

Install dependencies:

```bash
bundle install
```

Start MySQL and configure your connection using `MYSQL_USER`, `MYSQL_PASSWORD`,
and `MYSQL_SOCKET` environment variables. The default configuration uses user
`root` and socket `/private/tmp/jobplatform-mysql.sock`. See
`config/database.yml` for database settings.

Prepare the database and start the app:

```bash
bin/rails db:prepare
bin/rails server
```

Open <http://localhost:3000>.

New registrations are candidates. To make an account an employer for local
development, run `bin/rails console` and update the registered account:

```ruby
User.find_by!(email: "your-email@example.com").update!(role: "employer")
```

## Checks

```bash
bin/rails test
bin/rails zeitwerk:check
bin/rubocop
```

## OpenSearch search and reindex

The Jobs page uses OpenSearch when Keywords is filled in. It shows active jobs
only and can combine keywords with location, job type, and experience level.
Without keywords, the existing MySQL filters continue to work for all statuses.
Before starting OpenSearch, check whether it is already running:

```bash
curl http://127.0.0.1:9200
```

If this prints OpenSearch version information, use the running server and skip
the startup command. Starting a second copy against the same data directory
fails with a `failed to obtain node locks` error. If the check cannot connect,
start the development installation on this Mac:

```bash
OPENSEARCH_JAVA_OPTS="-Xms256m -Xmx256m" opensearch \
  -Ediscovery.type=single-node -Enetwork.host=127.0.0.1
```

In another terminal, populate the search index from existing MySQL jobs:

```bash
bin/rails jobs:reindex
```

Run this after first enabling search or if an OpenSearch outage leaves the index
behind MySQL. New, edited, and deleted jobs sync automatically after commit;
renaming a company updates its jobs' indexed company name. OpenSearch makes
new writes visible shortly after indexing. If it is offline, MySQL changes
still save and the app logs the sync failure; keyword search shows an unavailable
message until OpenSearch is running and the index is rebuilt.

To run the Phase 11 console smoke check, after creating at least one job:

```bash
bin/rails runner script/opensearch_check.rb
```

The check indexes an existing job, searches for it, and removes its temporary
index. It does not change MySQL data. Set `JOB_ID` to select a specific job.

`OPENSEARCH_URL` defaults to `http://127.0.0.1:9200`. `OPENSEARCH_INDEX` defaults
to `jobplatform_jobs_development` in development, with separate names for other
Rails environments. Restart Rails after changing these settings. The local
single-node configuration is for development; use a secured server for deployment.

The client is available as `OPENSEARCH_CLIENT` in `bin/rails console`, and
`Job#search_document` builds the searchable fields. Search currently returns
up to 1,000 matches; pagination comes in a later phase.

## Redis and Sidekiq

Check whether Redis is already running:

```bash
redis-cli ping
```

If it prints `PONG`, keep using that server. Otherwise, start the installed
local Redis in a separate terminal:

```bash
redis-server --bind 127.0.0.1
```

Start a Sidekiq worker in another terminal, alongside the Rails server:

```bash
bundle exec sidekiq -q default
```

Rails uses Sidekiq for Active Job in development and production. Tests use the
Rails test adapter, so the automated suite does not need Redis. Sidekiq uses
`redis://localhost:6379/0` by default; set the same `REDIS_URL` for the Rails
server and worker if your Redis address differs.

To verify processing, run this from the project directory while Redis and the
worker are running:

```bash
bin/rails runner 'SidekiqCheckJob.perform_later("manual-check")'
```

The worker terminal should print `Sidekiq check job completed: manual-check`.
This check job only writes a log line. OpenSearch indexing still runs
synchronously; moving it to Sidekiq is the next roadmap phase.
