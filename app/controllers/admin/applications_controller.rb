class Admin::ApplicationsController < Admin::BaseController
  def index
    authorize! :read, Application
    @applications_grid = initialize_grid(Application, include: [ :user, { job: :company } ],
                                         order: "applications.created_at", order_direction: "desc", per_page: 20)
  end

  def show
    @application = Application.includes(:user, job: :company).find(params[:id])
    authorize! :read, @application
  end
end
