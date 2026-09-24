class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  ROLES = %w[candidate employer admin].freeze

  has_one :company, dependent: :destroy
  has_many :applications, dependent: :destroy
  has_many :saved_jobs, dependent: :destroy
  has_many :notifications, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }
  validate :job_alert_filter_required, if: :job_alerts_enabled?

  before_validation :normalize_job_alert_filters
  before_save :reset_job_alert_cursor, if: :job_alert_preferences_changed?

  ROLES.each do |role_name|
    define_method("#{role_name}?") { role == role_name }
  end

  private

  def normalize_job_alert_filters
    %i[alert_location alert_job_type alert_experience_level].each do |attribute|
      self[attribute] = self[attribute]&.strip.presence
    end
  end

  def job_alert_filter_required
    return if [ alert_location, alert_job_type, alert_experience_level ].any?(&:present?)

    errors.add(:base, "Choose at least one job alert filter.")
  end

  def job_alert_preferences_changed?
    %i[job_alerts_enabled alert_location alert_job_type alert_experience_level].any? do |attribute|
      will_save_change_to_attribute?(attribute)
    end
  end

  def reset_job_alert_cursor
    self.last_job_alerted_at = nil
  end
end
