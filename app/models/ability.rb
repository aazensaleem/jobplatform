# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    can :read, [ Job, Company ]

    return unless user

    if user.admin?
      can :manage, :all
    elsif user.employer?
      can :read, :employer_dashboard
      can :create, Company
      can %i[update destroy], Company, user_id: user.id

      can :create, Job do |job|
        job.company.nil? || job.company.user_id == user.id
      end
      can %i[update destroy close], Job, company: { user_id: user.id }
      can :review_applicants, Job, company: { user_id: user.id }
      can %i[read update], Application, job: { company: { user_id: user.id } }
    elsif user.candidate?
      can :read, :candidate_dashboard
      can %i[create read], Application, user_id: user.id
      can %i[create read destroy], SavedJob, user_id: user.id
    end
  end
end
