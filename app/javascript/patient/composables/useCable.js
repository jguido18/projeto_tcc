import { createConsumer } from "@rails/actioncable"
import { useTriageStore } from "../stores/triage"
import { useRouter } from "vue-router"

let consumer = null

function getConsumer() {
  if (!consumer) consumer = createConsumer()
  return consumer
}

/**
 * Assina o TriageChannel para receber mensagens e mudanças de status em tempo real.
 * Retorna uma função de cleanup para desinscrever.
 */
export function useTriageChannel(sessionId) {
  const store  = useTriageStore()
  const router = useRouter()

  const subscription = getConsumer().subscriptions.create(
    { channel: "TriageChannel", session_id: sessionId },
    {
      received(data) {
        switch (data.type) {
          case "message":
            // Remove pending e insere mensagem real do servidor
            store.messages = store.messages.filter((m) => !m.pending)
            store.applyRealtimeMessage({
              id:                data.id || Date.now(),
              sender:            data.sender,
              content:           data.content,
              suggested_replies: data.suggested_replies || [],
              sent_at:           data.sent_at,
              sequence:          data.sequence,
            })
            break

          case "status_change":
            store.applyStatusChange(data.status)
            if (data.status === "awaiting_validation" ||
                data.status === "in_queue") {
              store.fetchStatus().then(() => router.push("/app/queue"))
            }
            break

          case "document_validation":
            store.applyDocumentValidation(data)
            break
        }
      },
    }
  )

  return () => subscription.unsubscribe()
}

/**
 * Assina o QueueChannel para receber atualizações de posição na fila.
 * @param {number} sessionId - ID da sessão de triagem
 * @param {Function} [onQueueUpdate] - Callback chamado em eventos que mudam a lista
 *   geral da fila (queued, position_update, called), para que a view possa
 *   recarregar o painel de espera.
 */
export function useQueueChannel(sessionId, { onQueueUpdate } = {}) {
  const store  = useTriageStore()
  const router = useRouter()

  const subscription = getConsumer().subscriptions.create(
    { channel: "QueueChannel", session_id: sessionId },
    {
      received(data) {
        switch (data.type) {
          case "queued":
            store.applyQueueEntry({
              ticket_number:  data.ticket_number,
              urgency_level:  data.urgency_level,
              urgency_label:  data.urgency_label,
              queue_position: data.position,
              status:         "waiting",
            })
            router.push("/app/queue")
            onQueueUpdate?.()
            break

          case "position_update":
            if (store.session?.queue_entry) {
              store.session.queue_entry.queue_position = data.position
            }
            onQueueUpdate?.()
            break

          case "called":
            if (store.session?.queue_entry) {
              store.session.queue_entry.status = "called"
            }
            onQueueUpdate?.()
            break
        }
      },
    }
  )

  return () => subscription.unsubscribe()
}
