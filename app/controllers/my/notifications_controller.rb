class My::NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @notifications = current_user.notifications.order(created_at: :desc, id: :desc)
  end

  def update
    notification = current_user.notifications.find(params[:id])
    authorize! :update, notification
    notification.update!(read_at: Time.current) unless notification.read_at?
    redirect_to my_notifications_path, status: :see_other
  end
end
