import { defineStore } from "pinia"
import { ref, computed } from "vue"
import { apiFetch, apiFetchFormData } from "../composables/useApi"

export const useTriageStore = defineStore("triage", () => {
  const session     = ref(null)   // dados da sessão vindos da API
  const messages    = ref([])     // histórico do chat
  const loaded      = ref(false)  // se já buscou status pela primeira vez
  const sending     = ref(false)  // aguardando resposta da IA
  const hintExample = ref("")     // sugestão de demanda inicial (vinda do TriageSetting)

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
      hintExample.value = data.hint_example || ""
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

  // file: File object or null
  async function sendMessage(content, file = null) {
    if (sending.value) return
    sending.value = true

    // Optimistic local message
    const optimisticContent = file ? `📎 ${file.name}${content ? " — " + content : ""}` : content
    messages.value.push({
      id:       Date.now(),
      sender:   "user",
      content:  optimisticContent,
      sent_at:  new Date().toISOString(),
      sequence: (messages.value.at(-1)?.sequence || 0) + 1,
      pending:  true,
    })

    try {
      let data
      if (file) {
        const formData = new FormData()
        formData.append("content", content || `Segue o documento: ${file.name}`)
        formData.append("file", file)
        data = await apiFetchFormData("/api/triage/message", formData)
      } else {
        data = await apiFetch("/api/triage/message", {
          method: "POST",
          body:   JSON.stringify({ content }),
        })
      }

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
      session.value.status        = "in_queue"
    }
  }

  // documentValidations: { [document_id]: { status, label, summary, confidence_score } }
  const documentValidations = ref({})

  function applyDocumentValidation(payload) {
    documentValidations.value[payload.document_id] = {
      status:          payload.validation_status,
      document_label:  payload.document_label,
      summary:         payload.summary,
      confidence_score: payload.confidence_score,
      issues_found:    payload.issues_found || [],
    }
  }

  return {
    session, messages, loaded, sending, hintExample,
    urgencyColor, urgencyMap,
    documentValidations,
    fetchStatus, fetchMessages, startTriage, sendMessage,
    finishTriage, restartTriage,
    applyRealtimeMessage, applyStatusChange, applyQueueEntry, applyDocumentValidation,
  }
})
