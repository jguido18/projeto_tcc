class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [ :edit, :update, :destroy ]

  ALLOWED_LIMITS = [ 10, 20, 50, 100 ].freeze

  def index
    collection = User.where("colaborador = true OR specialist = true").order(:name)

    @total_count       = collection.count
    @active_count      = collection.where(active: true).count
    @inactive_count    = collection.where(active: false).count
    @colaborador_count = collection.where(colaborador: true).count
    @specialist_count  = collection.where(specialist: true).count

    collection = collection.where(active: true)       if params[:status] == "active"
    collection = collection.where(active: false)      if params[:status] == "inactive"
    collection = collection.where(colaborador: true)  if params[:role] == "colaborador"
    collection = collection.where(specialist: true)   if params[:role] == "specialist"

    if params[:search].present?
      term = "%#{params[:search].strip}%"
      collection = collection.where("name ILIKE ? OR email ILIKE ?", term, term)
    end

    limit = params[:limit].to_i
    limit = 10 unless ALLOWED_LIMITS.include?(limit)
    @limit = limit
    @pagy  = Pagy::Offset.new(count: collection.count, page: params[:page], limit: @limit, request: request)
    @staff = @pagy.records(collection)

    # Quem desta página já participou de algum atendimento (não pode ser
    # excluído) — calculado em lote para não fazer consultas por linha.
    ids = @staff.map(&:id)
    @participant_ids = Set.new(
      TriageValidation.where(user_id: ids).distinct.pluck(:user_id) +
      TriageSession.where(checked_in_by_id: ids).distinct.pluck(:checked_in_by_id) +
      QueueEntry.where(called_by_id: ids).distinct.pluck(:called_by_id) +
      QueueEntry.where(finished_by_id: ids).distinct.pluck(:finished_by_id)
    )
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.active = true

    # Ensure at least one role is assigned
    unless @user.colaborador? || @user.specialist?
      @user.errors.add(:base, "Selecione ao menos um perfil (Colaborador ou Especialista).")
      render :new, status: :unprocessable_entity and return
    end

    if @user.save
      redirect_to admin_users_path, notice: "#{@user.name} criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    attrs = user_params
    attrs = attrs.except(:password, :password_confirmation) if attrs[:password].blank?

    if @user.update(attrs)
      redirect_to admin_users_path, notice: "#{@user.name} atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Quem já participou de qualquer etapa de um atendimento (validou, fez
  # check-in, chamou ou finalizou) não pode ser excluído: o histórico precisa
  # continuar mostrando quem fez cada coisa. Nesse caso o caminho é desativar.
  def destroy
    if @user.participated_in_attendance?
      redirect_to admin_users_path,
        alert: "#{@user.name} já participou de atendimentos e não pode ser excluído(a), para preservar o histórico. Para remover o acesso, edite o usuário e desative-o."
      return
    end

    if @user.destroy
      redirect_to admin_users_path, notice: "#{@user.name} foi removido(a)."
    else
      redirect_to admin_users_path,
        alert: "Não foi possível remover #{@user.name}: #{@user.errors.full_messages.to_sentence}"
    end
  end

  private

  def set_user
    @user = User.where("colaborador = true OR specialist = true").find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :cpf, :phone, :job_title, :active,
                                  :colaborador, :specialist, :password, :password_confirmation)
  end
end
