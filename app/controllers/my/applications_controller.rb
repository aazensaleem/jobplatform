class My::ApplicationsController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize! :read, :candidate_dashboard
    @applications = current_user.applications.includes(job: :company).order(created_at: :desc)
  end
end
