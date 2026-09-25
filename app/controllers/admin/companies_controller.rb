class Admin::CompaniesController < Admin::BaseController
  def index
    authorize! :read, Company
    @companies = Company.includes(:user).order(created_at: :desc, id: :desc)
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
