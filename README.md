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
- In-app notifications for applications, new applicants, and status changes
- Scheduled job expiry, daily candidate alerts, and weekly statistics
- Responsive navigation, forms, and tables
- Admin pages for users, companies, jobs, and applications
- Employer signup with admin approval or decline before posting

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

**Sign up** creates a candidate account. **Employer sign up** creates an
employer account that waits for admin review. Both options are in the signed-out
navigation.

## Employer approval

New employers sign in and return to the public Jobs page. They can browse jobs
and companies and manage their account while a persistent banner says their
request is pending. They cannot create or manage companies, post or manage jobs,
or review applicants until an admin approves them. The admin can filter users by
employer approval status and approve or decline a pending request from the user
detail page. A declined employer remains able to sign in and browse, sees a
clear declined message, and has no employer management permissions. An admin
can later approve a declined request. Existing employers were marked approved
when the migration ran, preserving their previous access.
If Rails was already running when this migration ran, use `bin/rails restart`
so the server loads the new User columns.

## Admin area

Sign in with an admin account and open **Admin** in the navigation, or visit
`/admin`. The area lists users, companies, jobs, and applications. Admins can
filter users by email, role, and employer approval, inspect a company's employer
and jobs, inspect application status and cover letter, close or delete jobs,
delete individual companies, and remove users. Deleting a company also deletes
its jobs and their applications, while keeping the employer's other companies.
Removing a user removes all their companies and related records; the signed-in
admin cannot remove their own account. Other roles get HTTP 403, and visitors
are sent to sign in.

## Notifications

Sign in and open **Notifications** in the navigation, or visit
`/my/notifications`. A successful application creates a confirmation for the
candidate and a new applicant notice for the job's employer. A real application
status change creates a new notice for the candidate. The navigation shows the
unread count, and each notice can be marked as read. Notices are stored in MySQL
as part of the application or status change; Redis, Sidekiq, and email settings
are not needed for this page.

Candidates can open **Job alerts** to enable daily matching by location, job
type, and/or experience level. Filled filters must all match. The first run
includes currently active matching jobs; later runs alert only for jobs created
since the previous run. Alerts appear as one summary in Notifications. They are
off until a candidate enables them.

## Scheduled jobs

Keep Redis and a Sidekiq worker running for the schedules in
`config/schedule.yml` to execute. The schedules are:

- Hourly, at minute 0: expire active jobs whose deadline has passed. The
  existing Job callback queues their OpenSearch updates.
- Daily, at 9:00 AM Asia/Karachi: create candidate job alert notifications.
- Monday, at 9:00 AM Asia/Karachi: log users, jobs, and applications added in
  the last seven days, plus current active and expired job counts.

For a manual check in the Rails console, run `ExpireJobsJob.perform_now`,
`DailyJobAlertsJob.perform_now`, or `WeeklyStatisticsJob.perform_now`.
`Sidekiq::Cron::Job.all` lists the registered schedules while Redis is running.
The first two manual commands can change job statuses or create notifications.

Job deadlines entered in forms and shown on job pages use Pakistan time (PKT).
Rails stores them in UTC. Applications stop at the deadline even if the hourly
expiry job has not run yet; the status changes to Expired when the next hourly
check executes. Keep Redis and Sidekiq running for that automatic status change.

## Checks

```bash
bin/rails test
bin/rails zeitwerk:check
bin/rubocop
```

## OpenSearch search and reindex

The Jobs page uses OpenSearch when Keywords is filled in. It shows active jobs
only. Every keyword must match a searchable field, including title, description,
company name, location, skills, or experience level. Separate location, job
type, and experience level fields apply exact filters.
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

Run this after first enabling search or if a queue or OpenSearch outage leaves
the index behind MySQL. New, edited, and deleted jobs enqueue indexing work after
commit; renaming a company enqueues its jobs too. Keep Redis and a Sidekiq worker
running to process these changes. Search results update after the worker finishes
and OpenSearch refreshes the documents. OpenSearch failures are retried by
Sidekiq; if Redis is unavailable, MySQL changes still save and the failed
enqueue is logged. Run `bin/rails jobs:reindex` after restoring a prolonged
outage to reconcile the full index.

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
This check job only writes a log line. Job creates, edits, deletes, and company
renames also enqueue work on the default queue. A queued index job reads the
current MySQL record when it runs, and a queued delete job removes the document
by ID.

## Employer listings

Employers can browse every listing on `/jobs`. Checking **Show only my job
listings** above the results refreshes that same page with jobs from only their
own companies. It works with the other filters and includes draft, active,
closed, and expired listings when no keyword is entered. Uncheck it to see all
jobs again.
