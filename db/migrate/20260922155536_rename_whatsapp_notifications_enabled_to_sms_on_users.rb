class RenameWhatsappNotificationsEnabledToSmsOnUsers < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :whatsapp_notifications_enabled, :sms_notifications_enabled
  end
end
