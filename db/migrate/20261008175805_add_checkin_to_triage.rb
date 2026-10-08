class AddCheckinToTriage < ActiveRecord::Migration[8.1]
  def change
    # Exige que o solicitante confirme presença no local (código exibido na TV
    # da recepção) antes de seguir para validação/fila.
    add_column :triage_settings, :require_checkin, :boolean, default: false, null: false
    # Triagem feita e sem check-in após esse prazo expira sozinha.
    add_column :triage_settings, :checkin_expiration_hours, :integer, default: 6, null: false

    add_column :triage_sessions, :checked_in_at, :datetime
  end
end
