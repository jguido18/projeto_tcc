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

  test "waiting_ordered_with_aging lets an aged low-urgency entry catch up to a fresher higher one" do
    # Verde parado há 3h (SLA 120min => 1 janela estourada => peso efetivo 3, empata com amarelo)
    aged_green = build_waiting_entry(urgency_level: "green", minutes_ago: 180)
    # Amarelo (peso 3) que acabou de chegar
    fresh_yellow = build_waiting_entry(urgency_level: "yellow", minutes_ago: 0)

    ordered = QueueEntry.waiting_ordered_with_aging

    # Empate de peso efetivo (3) é desempatado por ordem de chegada -> o verde envelhecido,
    # que chegou primeiro, vem antes do amarelo recém-chegado.
    assert_equal [ aged_green, fresh_yellow ], ordered
  end

  test "waiting_ordered_with_aging never lets aging overtake a genuinely more urgent case" do
    aged_green = build_waiting_entry(urgency_level: "green", minutes_ago: 600) # peso efetivo vira 1
    fresh_red  = build_waiting_entry(urgency_level: "red", minutes_ago: 0)     # peso 1 de verdade

    ordered = QueueEntry.waiting_ordered_with_aging

    # Peso efetivo empata (1), mas o vermelho chegou depois -> desempate por chegada:
    # o verde envelhecido só empata, nunca ultrapassa quem é vermelho de verdade.
    assert_equal [ aged_green, fresh_red ], ordered
  end

  private

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
