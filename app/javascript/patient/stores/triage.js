import { defineStore } from "pinia"
import { ref, computed } from "vue"
import { apiFetch } from "../composables/useApi"

export const useTriageStore = defineStore("triage", () => {
  const session  = ref(null)   // dados da sessão vindos da API
  const messages = ref([])     // histórico do chat
  const loaded   = ref(false)  // se já buscou status pela primeira vez
  const sending  = ref(false)  // aguardando resposta da IA

  // ── Urgência ──────────────────────────────────────────────────────

  const DEFAULT_URGENCY_COLOR = "#A0AEC0"

  const urgencyMap = computed(() => {
    const levels = session.value?.urgency_levels || []
    return levels.reduce((acc, level) => {
      acc[level.key] = level
      return acc
    }, {})
  })

  const urgencyColor = computed(() => {
    const level = session.value?.urgency_level ||
                  session.value?.queue_entry?.urgency_level
    return urgencyMap.value[level]?.color || DEFAULT_URGENCY_COLOR
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

  async function startTriage(initialDemand) {
    const data = await apiFetch("/api/triage/start", {
      method: "POST",
      body: JSON.stringify({ initial_demand: initialDemand }),
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

  async function finishTriage() {
    if (sending.value) return
    sending.value = true
    try {
      const data = await apiFetch("/api/triage/finish", {
        method: "POST",
      })

      if (data.session) session.value = data.session
      return data
    } finally {
      sending.value = false
    }
  }

  async function restartTriage() {
    if (sending.value) return
    sending.value = true
    try {
      await apiFetch("/api/triage/restart", {
        method: "POST",
      })

      session.value = null
      messages.value = []
      loaded.value = true
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
    urgencyColor, urgencyMap,
    fetchStatus, fetchMessages, startTriage, sendMessage,
    finishTriage, restartTriage,
    applyRealtimeMessage, applyStatusChange, applyQueueEntry,
  }
})
