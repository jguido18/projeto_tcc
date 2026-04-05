module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      # Retorna nil para conexões anônimas (ex: TV pública).
      # Canais que precisam de autenticação devem chamar reject explicitamente.
      if (user_id = cookies.encrypted[:user_id] || env["warden"]&.user&.id)
        User.find_by(id: user_id)
      end
    end
  end
end
