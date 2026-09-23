class SavedJobsController < ApplicationController
  before_action :authenticate_user!

  def create
    job = Job.find(params[:job_id])
    saved_job = current_user.saved_jobs.build(job: job)
    authorize! :create, saved_job

    if saved_job.save
      redirect_to job, notice: "Job saved.", status: :see_other
    else
      redirect_to job, alert: saved_job.errors.full_messages.to_sentence, status: :see_other
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to job, alert: "You have already saved this job.", status: :see_other
  end
end
