class DocumentProcessorService
  Result = Data.define(:type, :base64, :content_type, :text, :error)

  # raw_bytes:    String (binary) — already read from the uploaded file BEFORE ActiveStorage attach
  # content_type: String — MIME type of the file
  def initialize(raw_bytes, content_type)
    @raw_bytes    = raw_bytes
    @content_type = content_type
  end

  # Returns a Result with either:
  #   type: :image  → base64 + content_type (ready for vision API)
  #   type: :text   → text extracted from PDF
  #   type: :error  → error message
  def process
    unless TriageDocument::ALLOWED_CONTENT_TYPES.include?(@content_type)
      return error_result("Tipo de arquivo não permitido. Use JPG, PNG, WebP ou PDF.")
    end

    if @raw_bytes.bytesize > TriageDocument::MAX_FILE_SIZE
      return error_result("Arquivo muito grande. O limite é 10 MB.")
    end

    if @content_type.start_with?("image/")
      process_image
    else
      process_pdf
    end
  end

  private

  def process_image
    Result.new(
      type:         :image,
      base64:       Base64.strict_encode64(@raw_bytes),
      content_type: @content_type,
      text:         nil,
      error:        nil
    )
  end

  def process_pdf
    text = extract_pdf_text
    if text.present? && text.length > 80
      Result.new(type: :text, base64: nil, content_type: nil, text: text, error: nil)
    else
      error_result("PDF sem texto extraível. Por favor, envie uma foto do documento.")
    end
  rescue => e
    Rails.logger.error("[DocumentProcessorService] PDF error: #{e.message}")
    error_result("Não foi possível ler o PDF. Envie uma foto do documento.")
  end

  def extract_pdf_text
    require "pdf-reader"
    reader = PDF::Reader.new(StringIO.new(@raw_bytes))
    reader.pages.first(3).map(&:text).join("\n").strip
  end

  def error_result(message)
    Result.new(type: :error, base64: nil, content_type: nil, text: nil, error: message)
  end
end
