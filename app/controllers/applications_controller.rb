class ApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_application

  def new
  end

  def create
    @application.cover_letter = params.expect(application: [ :cover_letter ])[:cover_letter]
    # Serialize submissions for the same job and check its current status/deadline.
    @job.with_lock do
      if @application.save
        redirect_to my_applications_path, notice: "Application submitted.", status: :see_other
      else
        render :new, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::RecordNotUnique
    @application.errors.add(:base, "You have already applied for this job.")
    render :new, status: :unprocessable_entity
  end

  private

  def set_application
    @job = Job.find(params[:job_id])
    @application = current_user.applications.build(job: @job)
    authorize! :create, @application
  end
end
