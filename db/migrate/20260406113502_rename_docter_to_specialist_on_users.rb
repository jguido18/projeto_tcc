class RenameDocterToSpecialistOnUsers < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :doctor, :specialist
  end
end
