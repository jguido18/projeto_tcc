/**
 * Wrapper fetch que:
 * - Injeta automaticamente o CSRF token do Rails
 * - Serializa JSON e parseia a resposta
 * - Lança erro com a mensagem do servidor em caso de falha
 */
export async function apiFetch(url, options = {}) {
  const csrfToken = document
    .querySelector('meta[name="csrf-token"]')
    ?.getAttribute("content")

  const response = await fetch(url, {
    headers: {
      "Content-Type":  "application/json",
      "Accept":        "application/json",
      "X-CSRF-Token":  csrfToken || "",
    },
    ...options,
  })

  const json = await response.json()

  if (!response.ok) {
    throw new Error(json.error || `Erro ${response.status}`)
  }

  return json
}
