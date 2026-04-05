class Nursing::TriageValidationsController < Nursing::BaseController
  before_action :set_triage_session

  # GET /nursing/triage_validations/new?triage_session_id=X
  def new
    @ai_classification = @triage_session.ai_classification
    @validation = TriageValidation.new(
      final_urgency_level: @ai_classification.urgency_level
    )
    @urgency_levels = AiClassification::URGENCY_LEVELS
  end

  # POST /nursing/triage_validations
  def create
    @ai_classification = @triage_session.ai_classification
    @validation = TriageValidation.new(validation_params)
    @validation.ai_classification = @ai_classification
    @validation.user = current_user
    @validation.validated_at = Time.current

    if @validation.save
      QueueEntryService.new(@triage_session).enqueue
      @triage_session.update!(status: :validated)

      # Broadcast panel update to all nursing staff
      NursingChannel.broadcast_panel_update(current_establishment)

      redirect_to nursing_root_path,
        notice: t("app.flash.validation_success")
    else
      @urgency_levels = AiClassification::URGENCY_LEVELS
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_triage_session
    @triage_session = TriageSession
      .where(establishment: current_user.establishment)
      .find(params[:triage_session_id] || params.dig(:triage_validation, :triage_session_id))
  rescue ActiveRecord::RecordNotFound
    redirect_to nursing_root_path, alert: t("app.flash.session_not_found")
  end

  def validation_params
    params.require(:triage_validation).permit(:decision, :final_urgency_level, :notes)
  end
end
