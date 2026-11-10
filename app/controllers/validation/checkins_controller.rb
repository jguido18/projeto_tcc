class Validation::CheckinsController < Validation::BaseController
  # POST /validation/triage_sessions/:id/check_in
  # Check-in feito pela recepção — para quem não tem celular, ficou sem
  # bateria ou não conseguiu digitar o código da TV.
  def create
    session = TriageSession.find_by(id: params[:id])

    if session && TriageService.new(session).check_in!(by: current_user)
      redirect_to validation_root_path, notice: "Check-in de #{session.user.name} confirmado."
    else
      redirect_to validation_root_path, alert: "Esta triagem não está mais aguardando check-in."
    end
  end
end
