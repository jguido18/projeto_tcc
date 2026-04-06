import { createRouter, createWebHistory } from "vue-router"
import { useTriageStore } from "../stores/triage"

const routes = [
  {
    path: "/app",
    name: "home",
    component: () => import("../views/TriageStart.vue"),
  },
  {
    path: "/app/chat",
    name: "chat",
    component: () => import("../views/TriageChat.vue"),
  },
  {
    path: "/app/queue",
    name: "queue",
    component: () => import("../views/TriageQueue.vue"),
  },
  // Redireciona qualquer rota desconhecida para /app
  { path: "/:pathMatch(.*)*", redirect: "/app" },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

// Guard: redireciona para o passo correto conforme status da triagem
router.beforeEach(async (to) => {
  const store = useTriageStore()

  // Carrega status se ainda não foi carregado
  if (!store.loaded) {
    await store.fetchStatus()
  }

  const status = store.session?.status

  // Se não tem sessão ativa, vai para início
  if (!status && to.name !== "home") return { name: "home" }

  // Se está no chat mas sessão já avançou, redireciona para fila
  if (to.name === "chat" && status && !["in_triage"].includes(status)) {
    return { name: "queue" }
  }

  // Se está no início mas já tem sessão, redireciona
  if (to.name === "home" && status === "in_triage") return { name: "chat" }
  if (to.name === "home" && status && status !== "in_triage") return { name: "queue" }
})

export default router
