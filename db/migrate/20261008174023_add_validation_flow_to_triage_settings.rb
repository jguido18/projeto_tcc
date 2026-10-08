class AddValidationFlowToTriageSettings < ActiveRecord::Migration[8.1]
  def change
    # true = fluxo atual: a triagem da IA espera um colaborador validar antes
    # de entrar na fila. false = a classificação da IA já coloca o solicitante
    # direto na fila (ex.: secretaria, onde não há risco clínico).
    add_column :triage_settings, :require_staff_validation, :boolean, default: true, null: false

    # Permite ao especialista confirmar/ajustar a classificação da IA durante o
    # atendimento, quando ela não passou por validação da equipe.
    add_column :triage_settings, :specialist_review_enabled, :boolean, default: false, null: false
  end
end
