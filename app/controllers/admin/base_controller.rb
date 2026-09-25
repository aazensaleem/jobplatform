class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!

  private

  def authorize_admin!
    authorize! :access, :admin
  end
end
