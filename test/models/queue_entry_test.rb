require "test_helper"

class QueueEntryTest < ActiveSupport::TestCase
  setup do
    TriageSetting.delete_all
    TriageSetting.current # garante a config padrão (com sla_minutes por nível)
  end

  test "effective_urgency_weight rises by one level per full SLA window waited" do
    entry = build_waiting_entry(urgency_level: "green", minutes_ago: 180) # SLA verde = 120min

    # 180min / 120min de SLA = 1 janela completa estourada -> peso 4 -> 3 (amarelo)
    assert_equal 3, entry.effective_urgency_weight
  end

  test "effective_urgency_weight never drops below the most urgent configured weight" do
    entry = build_waiting_entry(urgency_level: "green", minutes_ago: 600) # muito além do SLA

    assert_equal QueueEntry::MIN_EFFECTIVE_WEIGHT, entry.effective_urgency_weight
  end

  test "effective_urgency_weight equals urgency_weight when the entry is not waiting" do
    entry = build_waiting_entry(urgency_level: "green", minutes_ago: 600)
    entry.update!(status: :called, called_at: Time.current)

    assert_equal entry.urgency_weight, entry.effective_urgency_weight
  end

  test "sla_breached? is true once waiting_minutes exceeds the level's sla_minutes" do
    fresh   = build_waiting_entry(urgency_level: "green", minutes_ago: 5)
    overdue = build_waiting_entry(urgency_level: "green", minutes_ago: 121)

    assert_not fresh.sla_breached?
    assert overdue.sla_breached?
  end

  test "waiting_ordered_with_aging lets an aged low-urgency entry overtake a fresher higher one" do
    # Verde parado há 4h (SLA 120min => 2 janelas estouradas => peso efetivo 2)
    aged_green = build_waiting_entry(urgency_level: "green", minutes_ago: 240)
    # Amarelo (peso 3) que acabou de chegar
    fresh_yellow = build_waiting_entry(urgency_level: "yellow", minutes_ago: 0)

    ordered = QueueEntry.waiting_ordered_with_aging

    # Peso efetivo 2 < 3 -> o verde envelhecido passa na frente do amarelo recém-chegado.
    assert_equal [ aged_green, fresh_yellow ], ordered
  end

  test "waiting_ordered_with_aging keeps a tied aged entry behind the level it caught up with" do
    # Verde parado há 3h (1 janela estourada => peso efetivo 3, empata com amarelo)
    aged_green = build_waiting_entry(urgency_level: "green", minutes_ago: 180)
    fresh_yellow = build_waiting_entry(urgency_level: "yellow", minutes_ago: 0)

    ordered = QueueEntry.waiting_ordered_with_aging

    # Empate de peso efetivo -> desempata pela urgência original: o amarelo de verdade vem
    # antes, mesmo tendo chegado depois.
    assert_equal [ fresh_yellow, aged_green ], ordered
  end

  test "waiting_ordered_with_aging never lets aging overtake a genuinely more urgent case" do
    aged_green = build_waiting_entry(urgency_level: "green", minutes_ago: 600) # peso efetivo vira 1
    fresh_red  = build_waiting_entry(urgency_level: "red", minutes_ago: 0)     # peso 1 de verdade

    ordered = QueueEntry.waiting_ordered_with_aging

    # Peso efetivo empata (1) -> desempata pela urgência original: o vermelho de verdade
    # vem antes, mesmo tendo chegado depois. O verde envelhecido só empata, nunca passa.
    assert_equal [ fresh_red, aged_green ], ordered
  end

  test "within the same original level, legal priority still beats arrival order" do
    early_adult = build_waiting_entry(urgency_level: "yellow", minutes_ago: 10)
    late_priority = build_waiting_entry(urgency_level: "yellow", minutes_ago: 5)
    late_priority.update!(priority_tier: 2)

    ordered = QueueEntry.waiting_ordered_with_aging

    assert_equal [ late_priority, early_adult ], ordered
  end

  test "average_service_minutes floors unrealistically short durations (test/demo data)" do
    3.times { build_completed_entry(duration_minutes: 0.5) } # chamar+finalizar em segundos

    assert_equal QueueEntry::MIN_SERVICE_MINUTES, QueueEntry.average_service_minutes
  end

  test "average_service_minutes returns the real average when it's already above the floor" do
    3.times { build_completed_entry(duration_minutes: 20) }

    assert_equal 20, QueueEntry.average_service_minutes
  end

  private

  def build_completed_entry(duration_minutes:)
    entry = build_waiting_entry(urgency_level: "green", minutes_ago: 60)
    called_at = 1.hour.ago
    entry.update!(
      status: :completed,
      called_at: called_at,
      service_finished_at: called_at + duration_minutes.minutes
    )
    entry
  end

  def build_waiting_entry(urgency_level:, minutes_ago:)
    user = User.create!(
      name: "Paciente #{SecureRandom.hex(4)}",
      email: "paciente-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      cpf: SecureRandom.hex(6)
    )
    session = TriageSession.create!(user: user, status: :in_queue, started_at: 1.hour.ago)
    queued_at = minutes_ago.minutes.ago

    QueueEntry.create!(
      triage_session: session,
      user: user,
      urgency_level: urgency_level,
      status: :waiting,
      queued_at: queued_at,
      ticket_number: SecureRandom.alphanumeric(9).upcase
    )
  end
end
