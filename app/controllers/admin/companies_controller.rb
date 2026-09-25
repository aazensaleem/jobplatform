class Admin::CompaniesController < Admin::BaseController
  def index
    authorize! :read, Company
    @companies_grid = initialize_grid(Company, include: [ :user, :jobs ],
                                      order: "companies.created_at", order_direction: "desc", per_page: 20)
  end

  def show
    @company = Company.includes(:user).find(params[:id])
    authorize! :read, @company
    @jobs = @company.jobs.order(created_at: :desc, id: :desc)
  end

  def destroy
    @company = Company.find(params[:id])
    authorize! :destroy, @company
    @company.destroy!
    redirect_to admin_companies_path, status: :see_other, notice: "Company deleted."
  end
end
