class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: %i[show approve decline destroy]

  def index
    authorize! :read, User
    filters = params.permit(:email, :role, :approval_status)
    @email = filters[:email].to_s.strip
    @role = filters[:role].to_s.strip
    @approval_status = filters[:approval_status].to_s.strip
    @pending_employers_count = User.where(role: "employer", employer_approval_status: "pending").count
    @users = User.order(created_at: :desc, id: :desc)
    @users = @users.where("email LIKE ?", "%#{User.sanitize_sql_like(@email)}%") if @email.present?
    @users = @users.where(role: @role) if @role.present?
    @users = @users.where(role: "employer", employer_approval_status: @approval_status) if @approval_status.present?
    @users_grid = initialize_grid(@users, order: "users.created_at", order_direction: "desc", per_page: 20)
  end

  def show
    authorize! :read, @user
  end

  def approve
    decide_employer!(%w[pending declined], "approved")
  end

  def decline
    decide_employer!(%w[pending], "declined")
  end

  def destroy
    authorize! :destroy, @user

    if @user == current_user
      redirect_to admin_user_path(@user), status: :see_other, alert: "You cannot remove your own account."
    else
      @user.destroy!
      redirect_to admin_users_path, status: :see_other, notice: "User removed."
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def decide_employer!(allowed_statuses, new_status)
    authorize! :update, @user
    changed = @user.with_lock do
      next false unless @user.employer? && allowed_statuses.include?(@user.employer_approval_status)

      @user.update!(employer_approval_status: new_status, employer_decided_at: Time.current)
      true
    end

    if changed
      redirect_to admin_user_path(@user), status: :see_other, notice: "Employer request #{new_status}."
    else
      redirect_to admin_user_path(@user), status: :see_other, alert: "This employer request cannot be #{new_status}."
    end
  end
end
