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

  ROLES.each do |role_name|
    define_method("#{role_name}?") { role == role_name }
  end
end
