/**
 * Wrapper fetch que:
 * - Injeta automaticamente o CSRF token do Rails
 * - Serializa JSON e parseia a resposta
 * - Lança erro com a mensagem do servidor em caso de falha
 *
 * O token é lido de dois lugares (em ordem de preferência):
 *   1. data-csrf no elemento #patient-app  (mais confiável no carregamento)
 *   2. <meta name="csrf-token">
 */
function getCsrfToken() {
  return (
    document.getElementById("patient-app")?.dataset?.csrf ||
    document.querySelector('meta[name="csrf-token"]')?.getAttribute("content") ||
    ""
  )
}

export async function apiFetch(url, options = {}) {
  const response = await fetch(url, {
    credentials: "same-origin",
    headers: {
      "Content-Type": "application/json",
      "Accept":       "application/json",
      "X-CSRF-Token": getCsrfToken(),
    },
    ...options,
  })

  // Se a resposta não for JSON (ex: HTML de erro), lança mensagem clara
  const contentType = response.headers.get("content-type") || ""
  if (!contentType.includes("application/json")) {
    throw new Error(
      response.status === 401
        ? "Sessão expirada. Faça login novamente."
        : `Erro inesperado do servidor (${response.status}).`
    )
  }

  const json = await response.json()

  if (!response.ok) {
    throw new Error(json.error || `Erro ${response.status}`)
  }

  return json
}

// Multipart variant — used when uploading files.
// Do NOT set Content-Type header; the browser sets it with the boundary automatically.
export async function apiFetchFormData(url, formData) {
  const response = await fetch(url, {
    method:      "POST",
    credentials: "same-origin",
    headers: {
      "Accept":       "application/json",
      "X-CSRF-Token": getCsrfToken(),
    },
    body: formData,
  })

  const contentType = response.headers.get("content-type") || ""
  if (!contentType.includes("application/json")) {
    throw new Error(
      response.status === 401
        ? "Sessão expirada. Faça login novamente."
        : `Erro inesperado do servidor (${response.status}).`
    )
  }

  const json = await response.json()

  if (!response.ok) {
    throw new Error(json.error || `Erro ${response.status}`)
  }

  return json
}
