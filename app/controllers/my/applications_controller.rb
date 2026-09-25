class My::ApplicationsController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize! :read, :candidate_dashboard
    @pagy, @applications = pagy(:offset, current_user.applications.includes(job: :company)
                                       .order(created_at: :desc, id: :desc), limit: 20)
  end
end
