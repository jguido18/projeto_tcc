class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [ :edit, :update, :destroy ]

  def index
    collection = User.where("colaborador = true OR specialist = true").order(:name)
    @pagy  = Pagy::Offset.new(count: collection.count, page: params[:page], limit: 10, request: request)
    @staff = @pagy.records(collection)
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

  def destroy
    @user.destroy!
    redirect_to admin_users_path, notice: "Usuário removido."
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to admin_users_path, alert: "Não é possível remover este usuário pois ele possui registros associados."
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
