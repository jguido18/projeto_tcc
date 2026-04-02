class CreateEstablishments < ActiveRecord::Migration[8.0]
  def change
    create_table :establishments do |t|
      t.string :name, null: false
      t.string :kind, null: false  # hospital, clinic, office, commerce
      t.string :cnpj
      t.string :phone
      t.string :address
      t.text :system_prompt, null: false
      t.string :urgency_protocol, null: false, default: "manchester"
      t.boolean :active, null: false, default: true
      t.jsonb :settings

      t.timestamps
    end

    add_index :establishments, :cnpj, unique: true, where: "cnpj IS NOT NULL"
    add_index :establishments, :kind
    add_index :establishments, :active
  end
end
