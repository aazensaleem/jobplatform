class JobsController < ApplicationController
  before_action :set_job, only: %i[show edit update destroy close]
  before_action :authenticate_user!, except: %i[index show]

  def index
    authorize! :read, Job
    @filters = params.permit(:location, :job_type, :experience_level, :status, :company_id)
                     .to_h.transform_values { |value| value.to_s.strip }.reject { |_, value| value.blank? }
    @jobs = Job.includes(:company).order(created_at: :desc)
    @jobs = @jobs.where(@filters.except("company_id"))
    if @filters["company_id"].present?
      @jobs = if @filters["company_id"].match?(/\A[1-9]\d*\z/)
        @jobs.where(company_id: @filters["company_id"])
      else
        @jobs.none
      end
    end
    @filter_companies = Company.order(:name)
  end

  def show
    authorize! :read, @job
    if current_user&.candidate?
      @existing_application = current_user.applications.find_by(job: @job)
      @saved_job = current_user.saved_jobs.find_by(job: @job)
    end
  end

  def new
    @job = Job.new
    authorize! :create, @job
    set_companies
    if current_user.employer?
      if @companies.empty?
        redirect_to new_company_path, notice: "Create your company before posting a job."
      else
        @job.company = @companies.first
      end
    end
  end

  def create
    @job = Job.new(job_params)
    authorize! :create, @job

    if @job.save
      redirect_to @job
    else
      set_companies
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize! :update, @job
    set_companies
  end

  def update
    authorize! :update, @job
    @job.assign_attributes(job_params)
    authorize! :update, @job

    if @job.save
      redirect_to @job
    else
      set_companies
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @job
    @job.destroy!
    redirect_to current_user.employer? ? employer_jobs_path : jobs_path, status: :see_other,
                notice: "Job deleted."
  end

  def close
    authorize! :close, @job

    if @job.update(status: "closed")
      redirect_to current_user.employer? ? employer_jobs_path : job_path(@job),
                  status: :see_other, notice: "Job closed."
    else
      set_companies
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_job
    @job = Job.find(params[:id])
  end

  def set_companies
    @companies = Company.order(:name)
    @companies = @companies.where(user_id: current_user.id) unless current_user.admin?
  end

  def job_params
    params.expect(job: %i[
      title
      description
      location
      job_type
      experience_level
      salary_min
      salary_max
      deadline
      status
      company_id
    ])
  end
end
