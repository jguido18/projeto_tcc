class ReplaceEstablishmentsWithTriageSettings < ActiveRecord::Migration[8.1]
  DEFAULT_SYSTEM_PROMPT = <<~PROMPT
    Você é um assistente de triagem do sistema TriagemAI.
    Seu papel é coletar informações essenciais com linguagem empática e objetiva.

    Fluxo da triagem:
    1. Cumprimente e confirme a queixa principal.
    2. Explore início, duração e intensidade dos sintomas.
    3. Pergunte sintomas associados relevantes para o contexto.
    4. Pergunte alergias, medicamentos em uso e doenças prévias.
    5. Conclua quando houver informações suficientes.

    Regras:
    - Faça uma pergunta por vez.
    - Use linguagem simples.
    - Ao finalizar, inclua obrigatoriamente o marcador [triagem_concluida].
    - Não use [triagem_concluida] cedo demais.
  PROMPT

  DEFAULT_URGENCY_LEVELS = [
    { key: "red", label: "Emergência", color: "#E53E3E", weight: 1 },
    { key: "orange", label: "Muito Urgente", color: "#DD6B20", weight: 2 },
    { key: "yellow", label: "Urgente", color: "#D69E2E", weight: 3 },
    { key: "green", label: "Pouco Urgente", color: "#38A169", weight: 4 },
    { key: "blue", label: "Não Urgente", color: "#3182CE", weight: 5 }
  ].freeze

  def up
    create_table :triage_settings do |t|
      t.text :purpose
      t.text :system_prompt, null: false
      t.jsonb :urgency_levels, null: false, default: []

      t.timestamps
    end

    add_index :triage_settings, :created_at

    if table_exists?(:establishments)
      establishment = select_one("SELECT system_prompt FROM establishments ORDER BY id ASC LIMIT 1")
      prompt = establishment&.fetch("system_prompt", nil).presence || DEFAULT_SYSTEM_PROMPT

      execute <<~SQL
        INSERT INTO triage_settings (purpose, system_prompt, urgency_levels, created_at, updated_at)
        VALUES (
          'Configuração global da IA de triagem',
          #{quote(prompt)},
          '#{DEFAULT_URGENCY_LEVELS.to_json}'::jsonb,
          NOW(),
          NOW()
        )
      SQL
    else
      execute <<~SQL
        INSERT INTO triage_settings (purpose, system_prompt, urgency_levels, created_at, updated_at)
        VALUES (
          'Configuração global da IA de triagem',
          #{quote(DEFAULT_SYSTEM_PROMPT)},
          '#{DEFAULT_URGENCY_LEVELS.to_json}'::jsonb,
          NOW(),
          NOW()
        )
      SQL
    end

    remove_reference :users, :establishment, foreign_key: true, index: true
    remove_reference :triage_sessions, :establishment, foreign_key: true, index: true
    remove_reference :queue_entries, :establishment, foreign_key: true, index: true

    drop_table :establishments
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "This migration removes the establishments table and references."
  end
end