class Employer::ApplicationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @job = Job.find(params[:job_id])
    authorize! :review_applicants, @job
    @applications = @job.applications.includes(:user).order(created_at: :desc)
  end

  def update
    @application = Application.find(params[:id])
    authorize! :update, @application
    @job = @application.job

    if @application.update(params.expect(application: [ :status ]))
      redirect_to employer_job_applications_path(@job), notice: "Application status updated.", status: :see_other
    else
      @applications = @job.applications.includes(:user).order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end
end
