class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :triage_session, optional: true

  enum :kind, {
    called_for_attendance: "called_for_attendance",
    position_updated:      "position_updated",
    triage_validated:      "triage_validated",
    cancellation:          "cancellation"
  }

  enum :channel, {
    websocket: "websocket",
    push:      "push",
    sms:       "sms"
  }

  validates :kind, presence: true
  validates :title, presence: true
  validates :body, presence: true
  validates :channel, presence: true

  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc) }

  def mark_as_read!
    update!(read: true, read_at: Time.current)
  end
end
