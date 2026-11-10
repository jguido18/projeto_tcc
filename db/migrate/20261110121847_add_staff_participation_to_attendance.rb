class AddStaffParticipationToAttendance < ActiveRecord::Migration[8.1]
  def change
    # Quem da equipe participou de cada etapa do atendimento. Além do histórico,
    # é o que impede excluir um membro da equipe que já atendeu alguém — a chave
    # estrangeira garante isso também no próprio banco.
    add_reference :queue_entries, :called_by, foreign_key: { to_table: :users }
    add_reference :queue_entries, :finished_by, foreign_key: { to_table: :users }
    add_reference :triage_sessions, :checked_in_by, foreign_key: { to_table: :users }
  end
end
