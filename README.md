# Job Marketplace

A Ruby on Rails application where employers post jobs and candidates apply for
roles and save listings.

## Features

- User registration and login with Devise
- Role-based permissions with CanCanCan
- Company and job management
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
