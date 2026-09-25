class Employer::JobsController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize! :read, :employer_dashboard
    @companies = Company.where(user_id: current_user.id).order(:name)
    @pagy, @jobs = pagy(:offset, Job.includes(:company).where(company_id: @companies.select(:id))
                                .order(created_at: :desc, id: :desc), limit: 20)
  end
end
