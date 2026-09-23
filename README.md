# Job Marketplace

A Ruby on Rails application where employers post jobs and candidates apply for
roles and save listings.

## Features

- User registration and login with Devise
- Role-based permissions with CanCanCan
- Company and job management
- Filter jobs by location, job type, experience level, status, and company
- OpenSearch connection and console indexing/search check
- Employer dashboard and applicant status updates
- Candidate applications and saved jobs

## Requirements

- Ruby 4.0.7
- Rails 8.1.3.1 (installed through Bundler)
- MySQL 8.2

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

## OpenSearch console check

OpenSearch is configured for console use; the website still uses MySQL filtering.
Start a local OpenSearch server before running the check. With the development
installation on this Mac:

```bash
OPENSEARCH_JAVA_OPTS="-Xms256m -Xmx256m" opensearch \
  -Ediscovery.type=single-node -Enetwork.host=127.0.0.1
```

In another terminal, after creating at least one job in the app:

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
`Job#search_document` builds the searchable fields. Job changes are not yet
automatically synchronized to OpenSearch.
