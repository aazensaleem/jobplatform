class Employer::JobsController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize! :read, :employer_dashboard
    @companies = Company.where(user_id: current_user.id).order(:name)
    @jobs = Job.includes(:company).where(company_id: @companies.select(:id)).order(created_at: :desc)
  end
end
