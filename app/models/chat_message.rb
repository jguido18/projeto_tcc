class ChatMessage < ApplicationRecord
  belongs_to :triage_session

  enum :sender, {
    user: "user",
    ai: "ai"
  }

  validates :sender, presence: true
  validates :content, presence: true
  validates :sequence, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :sent_at, presence: true
  validates :sequence, uniqueness: { scope: :triage_session_id }

  default_scope { order(:sequence) }
end
