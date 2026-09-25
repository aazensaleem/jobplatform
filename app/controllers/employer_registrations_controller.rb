class EmployerRegistrationsController < Devise::RegistrationsController
  protected

  def build_resource(hash = {})
    super
    resource.role = "employer"
    resource.employer_approval_status = "pending"
    resource
  end
end
