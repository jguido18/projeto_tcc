class AddPriorityFieldsToUsersAndQueue < ActiveRecord::Migration[8.1]
  def change
    # Condições permanentes, autodeclaradas no cadastro/perfil
    add_column :users, :pcd, :boolean, default: false, null: false # inclui TEA
    add_column :users, :obeso, :boolean, default: false, null: false
    add_column :users, :mobilidade_reduzida, :boolean, default: false, null: false

    # Condições temporárias — o próprio paciente informa até quando valem
    # (ver User#gestante_ativa?/lactante_ativa?/crianca_de_colo_ativa?)
    add_column :users, :gestante, :boolean, default: false, null: false
    add_column :users, :gestante_valid_until, :date
    add_column :users, :lactante, :boolean, default: false, null: false
    add_column :users, :lactante_valid_until, :date
    add_column :users, :crianca_de_colo, :boolean, default: false, null: false
    add_column :users, :crianca_de_colo_valid_until, :date

    # Snapshot calculado no momento em que o paciente entra na fila
    # (0 = sem prioridade, 1 = prioridade legal, 2 = superprioridade — idoso 80+)
    add_column :queue_entries, :priority_tier, :integer, default: 0, null: false
    add_column :queue_entries, :priority_reasons, :string, array: true, default: [], null: false

    remove_index :queue_entries, [ :urgency_weight, :queued_at ]
    add_index :queue_entries, [ :urgency_weight, :priority_tier, :queued_at ],
      name: "index_queue_entries_on_urgency_priority_queued_at"
  end
end
