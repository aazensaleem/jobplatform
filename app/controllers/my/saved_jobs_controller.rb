class My::SavedJobsController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize! :read, :candidate_dashboard
    @pagy, @saved_jobs = pagy(:offset, current_user.saved_jobs.includes(job: :company)
                                     .order(created_at: :desc, id: :desc), limit: 20)
  end

  def destroy
    saved_job = SavedJob.find(params[:id])
    authorize! :destroy, saved_job
    saved_job.destroy!
    redirect_to my_saved_jobs_path, notice: "Job removed from saved jobs.", status: :see_other
  end
end
