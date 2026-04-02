class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.references :establishment, null: false, foreign_key: { on_delete: :restrict }
      t.string :name, null: false
      t.string :cpf
      t.date :birth_date
      t.string :phone
      t.string :job_title

      # Access profile
      t.boolean :attendant, null: false, default: false
      t.boolean :admin, null: false, default: false

      # Devise
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at

      # Devise Trackable
      t.integer :sign_in_count, null: false, default: 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string :current_sign_in_ip
      t.string :last_sign_in_ip

      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :cpf, unique: true, where: "cpf IS NOT NULL"
    add_index :users, :attendant
    add_index :users, :admin
  end
end
