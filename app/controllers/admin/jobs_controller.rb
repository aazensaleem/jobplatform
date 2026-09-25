class Admin::JobsController < Admin::BaseController
  before_action :set_job, only: %i[close destroy]

  def index
    authorize! :read, Job
    @jobs_grid = initialize_grid(Job, include: { company: :user },
                                 order: "jobs.created_at", order_direction: "desc", per_page: 20,
                                 custom_order: { "jobs.company_id" => "companies.name" })
  end

  def close
    authorize! :close, @job
    @job.update!(status: "closed") unless @job.status == "closed"
    redirect_to admin_jobs_path, status: :see_other, notice: "Job closed."
  end

  def destroy
    authorize! :destroy, @job
    @job.destroy!
    redirect_to admin_jobs_path, status: :see_other, notice: "Job deleted."
  end

  private

  def set_job
    @job = Job.find(params[:id])
  end
end
