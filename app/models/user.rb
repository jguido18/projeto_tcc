class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable

  has_one_attached :avatar

  has_many :triage_sessions, dependent: :restrict_with_error
  has_many :queue_entries, dependent: :restrict_with_error
  has_many :notifications, dependent: :destroy
  has_many :triage_validations, dependent: :restrict_with_error

  validates :name, presence: true
  validates :cpf, presence: true, if: :patient?
  validates :cpf, uniqueness: { allow_blank: true }

  # Telefone só é obrigatório se o paciente ativar o aviso por SMS — sem
  # número não tem para onde mandar a mensagem quando ele for chamado.
  validates :phone, presence: { message: "é obrigatório para ativar o aviso por SMS" },
                     if: :sms_notifications_enabled?

  # Staff-only: job_title is required when user is colaborador or specialist
  validates :job_title, presence: true, if: -> { colaborador? || specialist? }

  # Altura/peso são opcionais (nem todo paciente informa), mas quando
  # informados precisam estar numa faixa humana plausível.
  validates :height_cm, numericality: { only_integer: true, greater_than: 50, less_than: 250 }, allow_nil: true
  validates :weight_kg, numericality: { greater_than: 1, less_than: 400 }, allow_nil: true

  # Admin can only be set by another admin — enforced at controller level
  # Only one role should be primary; a user can be colaborador + admin, or specialist + admin
  validate :staff_roles_consistency

  ELDERLY_AGE       = 60 # Estatuto do Idoso (Lei 10.741/2003)
  SUPER_ELDERLY_AGE = 80 # Subprioridade do próprio Estatuto do Idoso, art. 3º §2º

  # IMC ≥ 30 = obesidade (classificação padrão da OMS/Ministério da Saúde,
  # que engloba os graus I, II e III).
  OBESITY_BMI_THRESHOLD = 30

  # Condições temporárias: o paciente marca a caixa e informa até quando ela
  # vale. Passado esse prazo, a prioridade deixa de contar automaticamente.
  TEMPORARY_PRIORITY_FIELDS = {
    gestante:         :gestante_valid_until,
    lactante:         :lactante_valid_until,
    crianca_de_colo:  :crianca_de_colo_valid_until
  }.freeze

  validate :validate_temporary_priority_dates

  PRIORITY_REASON_LABELS = {
    super_elderly:       "Idoso (80+)",
    elderly:             "Idoso",
    pcd:                 "PCD",
    obeso:               "Obesidade",
    mobilidade_reduzida: "Mobilidade reduzida",
    gestante:            "Gestante",
    lactante:            "Lactante",
    crianca_de_colo:     "Criança de colo"
  }.freeze

  def staff?
    colaborador? || specialist? || admin?
  end

  def patient?
    !staff?
  end

  def age
    return nil unless birth_date

    today = Date.current
    years = today.year - birth_date.year
    years -= 1 if today < birth_date + years.years
    years
  end

  def elderly?
    age.present? && age >= ELDERLY_AGE
  end

  def super_elderly?
    age.present? && age >= SUPER_ELDERLY_AGE
  end

  # IMC = peso (kg) / altura (m)². nil quando falta altura ou peso — não dá
  # pra calcular, e não presumimos nada nesse caso.
  def bmi
    return nil if height_cm.blank? || weight_kg.blank?

    height_m = height_cm.to_f / 100
    (weight_kg.to_f / height_m**2).round(1)
  end

  # Obesidade não é mais autodeclarada — é calculada a partir do IMC, igual
  # ao idoso ser calculado a partir da data de nascimento (User#elderly?).
  def obeso?
    bmi.present? && bmi >= OBESITY_BMI_THRESHOLD
  end

  def gestante_ativa?
    gestante? && gestante_valid_until.present? && Date.current <= gestante_valid_until
  end

  def lactante_ativa?
    lactante? && lactante_valid_until.present? && Date.current <= lactante_valid_until
  end

  def crianca_de_colo_ativa?
    crianca_de_colo? && crianca_de_colo_valid_until.present? && Date.current <= crianca_de_colo_valid_until
  end

  # Motivos de prioridade legal ativos no momento (Lei 10.048/2000 + Estatuto do Idoso)
  def priority_reasons
    return [ :super_elderly ] if super_elderly?

    reasons = []
    reasons << :elderly if elderly?
    reasons << :pcd if pcd?
    reasons << :obeso if obeso?
    reasons << :mobilidade_reduzida if mobilidade_reduzida?
    reasons << :gestante if gestante_ativa?
    reasons << :lactante if lactante_ativa?
    reasons << :crianca_de_colo if crianca_de_colo_ativa?
    reasons
  end

  # 0 = sem prioridade · 1 = prioridade legal · 2 = superprioridade (idoso 80+)
  def priority_tier
    return 2 if super_elderly?
    priority_reasons.any? ? 1 : 0
  end

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :account_inactive
  end

  private

  def staff_roles_consistency
    if specialist? && colaborador?
      errors.add(:base, "A user cannot be both specialist and colaborador")
    end
  end

  # Quando o paciente marca uma condição temporária, a data de validade é
  # obrigatória e não pode ser anterior a hoje.
  def validate_temporary_priority_dates
    TEMPORARY_PRIORITY_FIELDS.each do |flag, date_field|
      next unless public_send(flag)

      date = public_send(date_field)
      if date.blank?
        errors.add(date_field, "deve ser informada")
      elsif date < Date.current
        errors.add(date_field, "não pode ser uma data no passado")
      end
    end
  end
end
