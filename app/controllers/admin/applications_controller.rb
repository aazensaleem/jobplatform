class Admin::ApplicationsController < Admin::BaseController
  def index
    authorize! :read, Application
    @applications = Application.includes(:user, job: :company).order(created_at: :desc, id: :desc)
  end

  def show
    @application = Application.includes(:user, job: :company).find(params[:id])
    authorize! :read, @application
  end
end
