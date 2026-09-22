class AddHeightAndWeightToUsersRemoveObeso < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :height_cm, :integer
    add_column :users, :weight_kg, :decimal, precision: 5, scale: 2

    # obeso deixa de ser autodeclarado e passa a ser calculado a partir do
    # IMC (altura/peso) — mesmo padrão já usado para idoso/super-idoso
    # (User#elderly?/#super_elderly?, calculados a partir de birth_date, sem
    # coluna própria).
    remove_column :users, :obeso, :boolean, default: false, null: false
  end
end
