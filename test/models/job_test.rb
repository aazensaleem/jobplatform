require "test_helper"

class JobTest < ActiveSupport::TestCase
  test "search document includes job and company fields without private account data" do
    job = jobs(:one)
    assert_equal({
      id: job.id, title: job.title, description: job.description,
      company_name: job.company.name, location: job.location,
      job_type: job.job_type, experience_level: job.experience_level,
      skills: [], status: job.status
    }, job.search_document)
    assert_not_includes job.search_document.to_json, job.company.user.email
  end

  test "search document is built from current MySQL values" do
    job = jobs(:one)
    job.update!(title: "Updated Rails role", status: "closed", location: nil)
    job.company.update!(name: "Updated company")
    document = job.reload.search_document
    assert_equal "Updated Rails role", document[:title]
    assert_equal "closed", document[:status]
    assert_equal "Updated company", document[:company_name]
    assert_nil document[:location]
  end
end
