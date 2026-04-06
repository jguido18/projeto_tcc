import { defineStore } from "pinia"
import { ref, computed } from "vue"
import { apiFetch } from "../composables/useApi"

export const useTriageStore = defineStore("triage", () => {
  const session  = ref(null)   // dados da sessão vindos da API
  const messages = ref([])     // histórico do chat
  const loaded   = ref(false)  // se já buscou status pela primeira vez
  const sending  = ref(false)  // aguardando resposta da IA

  // ── Urgência ──────────────────────────────────────────────────────

  const URGENCY_COLORS = {
    red:    "#E53E3E",
    orange: "#DD6B20",
    yellow: "#D69E2E",
    green:  "#38A169",
    blue:   "#3182CE",
  }

  const urgencyColor = computed(() => {
    const level = session.value?.urgency_level ||
                  session.value?.queue_entry?.urgency_level
    return URGENCY_COLORS[level] || "#A0AEC0"
  })

  // ── Actions ───────────────────────────────────────────────────────

  async function fetchStatus() {
    try {
      const data = await apiFetch("/api/triage/status")
      session.value = data.status !== "none" ? data : null
    } finally {
      loaded.value = true
    }
  }

  async function fetchMessages() {
    const data = await apiFetch("/api/triage/messages")
    messages.value = data.messages
  }

  async function startTriage(chiefComplaint) {
    const data = await apiFetch("/api/triage/start", {
      method: "POST",
      body: JSON.stringify({ chief_complaint: chiefComplaint }),
    })
    session.value = data
    await fetchMessages()
    return data
  }

  async function sendMessage(content) {
    if (sending.value) return
    sending.value = true
    try {
      // Adiciona mensagem do paciente localmente de imediato (UX responsivo)
      messages.value.push({
        id:       Date.now(),
        sender:   "user",
        content,
        sent_at:  new Date().toISOString(),
        sequence: (messages.value.at(-1)?.sequence || 0) + 1,
        pending:  true,
      })

      const data = await apiFetch("/api/triage/message", {
        method: "POST",
        body: JSON.stringify({ content }),
      })

      // Remove mensagens pendentes e recarrega do servidor
      messages.value = messages.value.filter((m) => !m.pending)
      await fetchMessages()

      if (data.session) session.value = data.session
      return data
    } finally {
      sending.value = false
    }
  }

  function applyRealtimeMessage(msg) {
    // Evita duplicata
    if (messages.value.find((m) => m.id === msg.id)) return
    messages.value.push(msg)
  }

  function applyStatusChange(status) {
    if (session.value) session.value.status = status
  }

  function applyQueueEntry(entry) {
    if (session.value) {
      session.value.queue_entry   = entry
      session.value.urgency_level = entry.urgency_level
      session.value.urgency_label = entry.urgency_label
    }
  }

  return {
    session, messages, loaded, sending,
    urgencyColor,
    fetchStatus, fetchMessages, startTriage, sendMessage,
    applyRealtimeMessage, applyStatusChange, applyQueueEntry,
  }
})
