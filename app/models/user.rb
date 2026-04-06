class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable

  has_many :triage_sessions, dependent: :restrict_with_error
  has_many :queue_entries, dependent: :restrict_with_error
  has_many :notifications, dependent: :destroy
  has_many :triage_validations, dependent: :restrict_with_error

  validates :name, presence: true

  # Staff-only: job_title is required when user is attendant or doctor
  validates :job_title, presence: true, if: -> { attendant? || doctor? }

  # Admin can only be set by another admin — enforced at controller level
  # Only one role should be primary; a user can be attendant + admin, or doctor + admin
  validate :staff_roles_consistency

  def staff?
    attendant? || doctor? || admin?
  end

  def patient?
    !staff?
  end

  private

  def staff_roles_consistency
    if doctor? && attendant?
      errors.add(:base, "A user cannot be both doctor and attendant")
    end
  end
end
