class TriageDocument < ApplicationRecord
  belongs_to :triage_session
  belongs_to :chat_message, optional: true
  has_one_attached :file

  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp application/pdf].freeze
  MAX_FILE_SIZE         = 10.megabytes
  DOCUMENT_TYPES        = %w[rg cpf cnh passaporte comprovante outro desconhecido].freeze

  # suffix: :doc avoids conflict with AR's built-in valid? method
  enum :validation_status, {
    pending:   "pending",
    valid:     "valid",
    invalid:   "invalid",
    uncertain: "uncertain",
    skipped:   "skipped"
  }, suffix: :doc

  validates :validation_status, presence: true

  def image?
    content_type&.start_with?("image/")
  end

  def pdf?
    content_type == "application/pdf"
  end

  def doc_validated?
    valid_doc? || invalid_doc? || uncertain_doc?
  end

  def validation_summary
    return nil unless doc_validated?
    validation_result&.dig("summary")
  end

  def document_type_label
    {
      "rg"           => "RG",
      "cpf"          => "CPF",
      "cnh"          => "CNH",
      "passaporte"   => "Passaporte",
      "comprovante"  => "Comprovante",
      "outro"        => "Outro documento",
      "desconhecido" => "Documento"
    }[document_type] || "Documento"
  end
end
