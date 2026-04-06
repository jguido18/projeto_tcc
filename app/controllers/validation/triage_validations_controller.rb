class Validation::TriageValidationsController < Validation::BaseController
  before_action :set_triage_session

  # GET /validation/triage_validations/new?triage_session_id=X
  def new
    @ai_classification = @triage_session.ai_classification
    @validation = TriageValidation.new(
      final_urgency_level: @ai_classification.urgency_level
    )
    @urgency_levels = TriageSetting.current.urgency_levels
  end

  # POST /validation/triage_validations
  def create
    @ai_classification = @triage_session.ai_classification
    @validation = TriageValidation.new(validation_params)
    @validation.ai_classification = @ai_classification
    @validation.user = current_user
    @validation.validated_at = Time.current

    if @validation.save
      # enqueue handles the status transition to :in_queue internally
      QueueEntryService.new(@triage_session).enqueue

      # Broadcast panel update to all validation staff
      ValidationPanelChannel.broadcast_update

      redirect_to validation_root_path,
        notice: t("app.flash.validation_success")
    else
      @urgency_levels = TriageSetting.current.urgency_levels
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_triage_session
    @triage_session = TriageSession
      .find(params[:triage_session_id] || params.dig(:triage_validation, :triage_session_id))
  rescue ActiveRecord::RecordNotFound
    redirect_to validation_root_path, alert: t("app.flash.session_not_found")
  end

  def validation_params
    params.require(:triage_validation).permit(:decision, :final_urgency_level, :notes)
  end
end
