require "test_helper"

class JobFilteringTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @first = jobs(:one)
    @first.update!(title: "Rails developer", location: "Lahore", job_type: "remote",
                   experience_level: "junior", status: "active", created_at: 2.days.ago)
    @second = jobs(:two)
    @second.update!(title: "Senior developer", location: "Karachi", job_type: "onsite",
                    experience_level: "senior", status: "closed", created_at: 1.day.ago)
  end

  test "public listing filters each supported field" do
    { location: "Lahore", job_type: "remote", experience_level: "junior",
      status: "active", company_id: @first.company_id.to_s }.each do |field, value|
      get jobs_path, params: { field => value }
      assert_response :success
      assert_select "tbody tr", count: 1
      assert_select "tbody a[href=?]", job_path(@first)
      assert_select "tbody a[href=?]", job_path(@second), count: 0
    end
  end

  test "filters combine and preserve form values with a clear link" do
    get jobs_path, params: { location: " Lahore ", job_type: "remote", experience_level: "junior",
                             status: "active", company_id: @first.company_id }
    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "input[name=location][value=Lahore]"
    assert_select "input[name=job_type][value=remote]"
    assert_select "input[name=experience_level][value=junior]"
    assert_select "select[name=status] option[selected][value=active]"
    assert_select "select[name=company_id] option[selected][value=?]", @first.company_id.to_s
    assert_select "a[href=?]", jobs_path, text: "Clear filters"
    assert_select "form[method=get][action=?]", jobs_path

    get jobs_path, params: { location: "Lahore", status: "closed" }
    assert_response :success
    assert_select "tbody tr", count: 0
    assert_select "p", text: "No jobs match your filters."
  end

  test "blank filters and clear URL preserve all statuses with active jobs first" do
    [ {}, { location: "  ", job_type: "", experience_level: " ", status: "", company_id: "" } ].each do |filters|
      get jobs_path, params: filters
      assert_response :success
      assert_select "tbody tr", count: 2
      assert_select "tbody tr:first-child td:first-child", text: @first.title
    end
    get root_path, params: { status: "closed" }
    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "tbody a[href=?]", job_path(@second)
  end

  test "public listing puts expired jobs last and keeps newest first within each status" do
    newer_active = @first.company.jobs.create!(title: "Newer active", description: "Details",
                                               status: "active", created_at: 1.hour.ago)
    newer_expired = @first.company.jobs.create!(title: "Newer expired", description: "Details",
                                                status: "expired", created_at: Time.current)
    older_expired = @first.company.jobs.create!(title: "Older expired", description: "Details",
                                                status: "expired", created_at: 3.days.ago)

    get jobs_path

    assert_response :success
    assert_equal [ newer_active, @first, @second, newer_expired, older_expired ].map(&:title),
                 css_select("tbody tr td:first-child a").map(&:text)
  end

  test "text values are literal full matches and unknown values give empty results" do
    [ { location: "Lah" }, { location: "%" }, { job_type: "' OR 1=1 --" },
      { experience_level: "unknown" }, { status: "unknown" },
      { company_id: "999999999999999999999999999" },
      { company_id: "#{@first.company_id}oops" }, { company_id: "0" } ].each do |filters|
      get jobs_path, params: filters
      assert_response :success
      assert_select "tbody tr", count: 0
      assert_select "p", text: "No jobs match your filters."
    end
  end

  test "unsupported and nonscalar parameters cannot alter the query" do
    get jobs_path, params: { title: "Missing", user_id: users(:one).id,
                             location: [ "Missing" ], status: { value: "active" } }
    assert_response :success
    assert_select "tbody tr", count: 2
  end

  test "filtering works for candidates without exposing management controls" do
    sign_in users(:one)
    get jobs_path, params: { location: "Lahore" }
    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "a[href=?]", edit_job_path(@first), count: 0
    assert_select "form[action=?]", job_path(@first), count: 0
  end
end
