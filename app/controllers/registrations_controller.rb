class RegistrationsController < Devise::RegistrationsController
  protected

  # Para esta fase do projeto, todos os pacientes são registrados no estabelecimento 1.
  # Futuramente, com multi-tenant, o estabelecimento será selecionado pelo paciente ou
  # derivado do subdomínio/token de acesso.
  def build_resource(hash = {})
    hash[:establishment_id] ||= 1
    super
  end
end
