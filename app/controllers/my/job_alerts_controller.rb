class My::JobAlertsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_candidate!

  def edit
  end

  def update
    current_user.assign_attributes(params.expect(user: %i[
      job_alerts_enabled alert_location alert_job_type alert_experience_level
    ]))

    if current_user.save
      redirect_to my_job_alerts_path, notice: "Job alert preferences saved.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def authorize_candidate!
    authorize! :read, :candidate_dashboard
  end
end
