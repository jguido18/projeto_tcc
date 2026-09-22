class Admin::TriageSettingsController < Admin::BaseController
  before_action :set_triage_setting

  def edit
  end

  def update
    @triage_setting.assign_attributes(triage_setting_params)

    if @triage_setting.save
      redirect_to edit_admin_triage_setting_path, notice: "Configuração da IA atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_triage_setting
    @triage_setting = TriageSetting.current
  end

  def triage_setting_params
    base = params.require(:triage_setting).permit(:purpose, :system_prompt, :hint_example, :confidence_threshold)

    raw_levels = params.dig(:triage_setting, :urgency_levels)
    urgency_levels = case raw_levels
    when ActionController::Parameters
      raw_levels.to_unsafe_h.values
    when Array
      raw_levels
    else
      []
    end

    cleaned = urgency_levels.filter_map do |level|
      level_hash = case level
      when ActionController::Parameters
        level.permit(:key, :label, :color, :weight, :sla_minutes).to_h
      when Hash
        level.slice("key", "label", "color", "weight", "sla_minutes")
      else
        nil
      end

      level_hash if level_hash.present?
    end

    {
      purpose:               base[:purpose],
      system_prompt:         base[:system_prompt],
      hint_example:          base[:hint_example],
      confidence_threshold:  base[:confidence_threshold],
      urgency_levels:        cleaned
    }
  end
end
