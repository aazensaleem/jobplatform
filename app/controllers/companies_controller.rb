class CompaniesController < ApplicationController
  before_action :set_company, only: %i[show edit update destroy]
  before_action :authenticate_user!, except: %i[index show]

  def index
    authorize! :read, Company
    companies = current_user&.employer_approved? ? Company.where(user: current_user) : Company.all
    @companies = companies.includes(:user).order(:name)
  end

  def show
    authorize! :read, @company
    @jobs = @company.jobs.order(created_at: :desc)
  end

  def new
    @company = Company.new
    authorize! :create, @company
    set_employers
  end

  def create
    @company = Company.new(company_params)
    @company.user = current_user unless current_user.admin?
    authorize! :create, @company

    if @company.save
      redirect_to @company
    else
      set_employers
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize! :update, @company
    set_employers
  end

  def update
    authorize! :update, @company

    if @company.update(company_params)
      redirect_to @company
    else
      set_employers
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @company
    @company.destroy!
    redirect_to companies_path
  end

  private

  def set_company
    @company = Company.find(params[:id])
  end

  def company_params
    permitted_attributes = %i[name description location]
    permitted_attributes << :user_id if current_user.admin?
    params.expect(company: permitted_attributes)
  end

  def set_employers
    @employers = User.where(role: "employer").order(:email)
    @employers = @employers.where(id: current_user.id) unless current_user.admin?
  end
end
