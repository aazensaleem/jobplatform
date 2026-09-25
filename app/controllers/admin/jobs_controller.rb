class Admin::JobsController < Admin::BaseController
  before_action :set_job, only: %i[close destroy]

  def index
    authorize! :read, Job
    @jobs = Job.includes(company: :user).order(created_at: :desc, id: :desc)
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
