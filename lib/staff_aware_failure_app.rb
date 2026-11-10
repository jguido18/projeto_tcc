# Falhas de autenticação vindas da área da equipe (login de equipe, painéis de
# validação/atendimento/admin) voltam para o login da equipe (/staff/login),
# e não para o login de solicitante (/login), que é o padrão do Devise.
#
# O caso que motivou isso: conta de equipe desativada. O Devise a rejeita num
# hook depois da senha conferir, por um caminho que não respeita o "recall"
# da tela de login de equipe — e a pessoa caía na tela de solicitante.
class StaffAwareFailureApp < Devise::FailureApp
  STAFF_PATH_PREFIXES = %w[/staff /validation /attendance /admin].freeze

  def redirect_url
    staff_area? ? new_staff_session_path : super
  end

  private

  def staff_area?
    STAFF_PATH_PREFIXES.any? { |prefix| attempted_path.to_s.start_with?(prefix) }
  end
end
