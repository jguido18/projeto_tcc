class Establishment < ApplicationRecord
  has_many :users, dependent: :restrict_with_error
  has_many :triage_sessions, dependent: :restrict_with_error
  has_many :queue_entries, dependent: :restrict_with_error

  enum :kind, {
    hospital: "hospital",
    clinic: "clinic",
    office: "office",
    commerce: "commerce"
  }

  enum :urgency_protocol, {
    manchester: "manchester"
  }

  validates :name, presence: true
  validates :kind, presence: true
  validates :system_prompt, presence: true
  validates :urgency_protocol, presence: true
  validates :cnpj, uniqueness: true, allow_nil: true
end
