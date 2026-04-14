class AddHintExampleToTriageSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :triage_settings, :hint_example, :string
  end
end
