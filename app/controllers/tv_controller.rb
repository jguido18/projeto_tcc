class TvController < ApplicationController
  # Tela pública — não exige autenticação
  skip_before_action :authenticate_user!, raise: false

  # Ativar/desativar o navegador como "TV da recepção" exige alguém da equipe.
  before_action :require_staff!, only: %i[activate deactivate]

  layout "tv"

  TV_DEVICE_COOKIE = :tv_device

  def show
    @called_entries = QueueEntry
      .includes(triage_session: :user)
      .where(status: :called)
      .order(called_at: :desc)

    # A lista de chamadas é pública, mas o código de check-in só aparece na TV
    # autorizada — senão qualquer pessoa abriria /tv de casa e copiaria o código.
    @show_checkin = TriageSetting.current.require_checkin? && tv_device?
  end

  # GET /tv/checkin_code — código atual + QR, consultado periodicamente pela TV.
  def checkin_code
    unless TriageSetting.current.require_checkin? && tv_device?
      head :forbidden
      return
    end

    code = CheckinCode.current
    render json: {
      code: code,
      qr_svg: RQRCode::QRCode.new(checkin_url(code)).as_svg(
        module_size: 6, viewbox: true, use_path: true, standalone: true, color: "000"
      ),
      seconds_remaining: CheckinCode.seconds_remaining
    }
  end

  # POST /tv/activate — marca ESTE navegador como a TV da recepção.
  # Basta fazer uma vez, logado como equipe; depois pode sair da conta.
  def activate
    cookies.permanent.signed[TV_DEVICE_COOKIE] = { value: "reception", httponly: true }
    redirect_to queue_tv_path
  end

  # POST /tv/deactivate — este navegador deixa de exibir o código de check-in.
  def deactivate
    cookies.delete(TV_DEVICE_COOKIE)
    redirect_to edit_admin_triage_setting_path, notice: "Este navegador não exibe mais o código de check-in."
  end

  private

  def tv_device?
    cookies.signed[TV_DEVICE_COOKIE] == "reception"
  end

  # O QR leva direto para a tela de fila do app com o código já preenchido.
  def checkin_url(code)
    "#{request.base_url}/app/queue?checkin=#{code}"
  end
end
