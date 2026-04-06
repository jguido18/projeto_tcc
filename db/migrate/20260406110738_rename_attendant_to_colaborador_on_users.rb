class RenameAttendantToColaboradorOnUsers < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :attendant, :colaborador
  end
end
