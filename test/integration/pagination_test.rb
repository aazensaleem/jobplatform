require "test_helper"

class PaginationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @candidate = users(:one)
    @employer = users(:two)
    @company = companies(:one)
    @new_jobs = 21.times.map do |index|
      @company.jobs.create!(title: "Paginated role #{index}", description: "Description",
                            status: "active", deadline: 1.year.from_now)
    end
    @new_jobs.each do |job|
      @candidate.applications.create!(job: job)
      @candidate.saved_jobs.create!(job: job)
    end
  end

  test "public jobs and owned job lists show bounded pages" do
    get jobs_path, params: { company_id: @company.id }
    assert_response :success
    assert_select "tbody tr", count: 20
    assert_select ".pagination a[href*='page=2'][href*='company_id=']"

    get jobs_path, params: { company_id: @company.id, page: 2 }
    assert_response :success
    assert_select "tbody tr", count: 2
    assert_select "tbody a[href=?]", job_path(jobs(:two)), count: 0

    sign_in @employer
    get jobs_path, params: { my_jobs: "1" }
    assert_response :success
    assert_select "tbody tr", count: 20
    assert_select ".pagination a[href*='page=2'][href*='my_jobs=1']"
    get jobs_path, params: { my_jobs: "1", page: 2 }
    assert_select "tbody tr", count: 2
    assert_select "tbody a[href=?]", job_path(jobs(:two)), count: 0

    get employer_jobs_path
    assert_response :success
    assert_select "tbody tr", count: 20
    assert_select ".pagination a[href*='page=2']"
    get employer_jobs_path, params: { page: 2 }
    assert_select "tbody tr", count: 2
    assert_select "tbody a[href=?]", job_path(jobs(:two)), count: 0
  end

  test "candidate application and saved job lists paginate within ownership" do
    sign_in @candidate
    [ my_applications_path, my_saved_jobs_path ].each do |path|
      get path
      assert_response :success
      assert_select "tbody tr", count: 20
      assert_select ".pagination a[href*='page=2']"
      get path, params: { page: 2 }
      assert_response :success
      assert_select "tbody tr", count: 2
      assert_select "tbody a[href=?]", job_path(jobs(:two)), count: 0
    end
  end

  test "keyword search keeps its filters across pages" do
    ids = @new_jobs.map(&:id)
    service = Struct.new(:job_ids).new(ids)
    with_stubbed_method(JobSearchService, :new, ->(**) { service }) do
      get jobs_path, params: { q: "Rails", company_id: @company.id }
      assert_response :success
      assert_select "tbody tr", count: 20
      assert_select ".pagination a[href*='page=2'][href*='q=Rails'][href*='company_id=']"

      get jobs_path, params: { q: "Rails", company_id: @company.id, page: 2 }
      assert_response :success
      assert_select "tbody tr", count: 1
      assert_select "tbody a[href=?]", job_path(@new_jobs.last)
    end
  end
end
