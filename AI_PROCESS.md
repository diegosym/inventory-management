# Proceso de desarrollo — Uso de IA

## Por qué ser transparente

Esta aplicación fue construida con asistencia de inteligencia artificial. Quiero ser
explícito sobre eso porque creo que **saber usar IA de forma efectiva es una habilidad
de ingeniería real**, no un atajo que deba ocultarse. La pregunta no es "¿usaste IA?",
sino "¿qué decidiste tú y qué le delegaste a la máquina?".

Este documento responde esa pregunta con precisión.

---

## La herramienta: OpenCode + MiMo-V2.6-Flash

Usé **[OpenCode](https://opencode.ai)**, un entorno de desarrollo agéntico de línea de
comandos, con el modelo **MiMo-V2.6-Flash** como motor de inferencia. No usé ninguna
otra herramienta de IA (ni Claude directamente, ni GitHub Copilot, ni ChatGPT).

MiMo-V2.6-Flash es un modelo relativamente pequeño comparado con GPT-4 o Claude 3.5.
Eso implicó que el sistema que diseñé debía ser más preciso: prompts estructurados,
gates de aprobación explícitos y separación clara de responsabilidades entre agentes
para que el modelo pudiera ejecutar correctamente dentro de un scope acotado.

---

## El sistema que diseñé: flujo SDD multi-agente

No usé la IA como un chatbot al que le pedía código. Diseñé un **sistema de desarrollo
guiado por especificaciones (SDD)** con 4 agentes especializados, cada uno con
permisos acotados sobre el filesystem del proyecto.

### El ciclo completo

```
Constitution → Spec → Clarification → Plan → Tasks → Implementation → Validation
```

Cada flecha es un **gate de aprobación explícito**. Sin mi aprobación, el flujo no
avanza. Los agentes no pueden saltarse un gate ni resolver por su cuenta una decisión
que me corresponde a mí.

| Fase | Quién | Qué produce |
|---|---|---|
| Constitution | Yo (con asistencia del planner) | `docs/constitution.md` — 17 principios no negociables |
| Spec | Planner | `specs/NNN/spec.md` — requisitos en formato EARS, casos límite, fuera de alcance |
| Clarification | Reviewer | Lista de ambigüedades y contradicciones (solo detecta, no resuelve) |
| **Aprobación** | **Yo** | **Gate: la spec no avanza sin mi OK explícito** |
| Plan | Planner | `specs/NNN/plan.md` — archivos, decisiones técnicas, estrategia de tests |
| **Aprobación** | **Yo** | **Gate: ningún código se escribe sin mi OK del plan** |
| Tasks | Planner | `specs/NNN/tasks.md` — tareas en orden de dependencia con "Done when:" verificable |
| Implementation | Implementer | Código + tests (tests primero, en rojo) + commit por tarea |
| Validation | Reviewer | Verificación RF por RF: `VEREDICTO: APROBADO` o `CAMBIOS NECESARIOS` |

### Los 4 agentes y sus responsabilidades

**Coordinator** (agente primario)
- Único que habla con el usuario.
- Único que puede editar `MEMORY.md`.
- Puede delegar trabajo a los 3 subagentes.
- No escribe código ni edita specs.
- Verifica que cada commit del implementer sea real (`git show`) antes de aceptar una tarea como hecha.

**Planner** (subagente)
- Solo puede escribir dentro de `specs/`.
- No puede tocar `backend/`, `frontend/`, ni ningún archivo de código.
- Si necesita registrar una decisión técnica, se la reporta al coordinator — él la escribe en `MEMORY.md`.
- Sin acceso a internet (`webfetch: deny`).

**Implementer** (subagente)
- Solo puede editar `backend/`, `frontend/`, `docker-compose.yml`, `Dockerfile*`, `README.md` e infraestructura asociada.
- No puede tocar `specs/` (excepto marcar tareas como completadas en `tasks.md`).
- Implementa **una tarea a la vez**: tests primero (en rojo), luego código, luego commit.
- Si la tarea o el plan son incorrectos o imposibles, para y reporta — nunca improvisa.

**Reviewer** (subagente)
- **Nunca edita ningún archivo.**
- Solo puede ejecutar los comandos de verificación documentados en `MEMORY.md`:
  `bundle exec rspec`, `npm test`, `npm run build`, `docker compose ps/logs`.
- En validación: recorre cada RF de la spec, verifica con evidencia real (no supone), y
  emite siempre `VEREDICTO: APROBADO` o `VEREDICTO: CAMBIOS NECESARIOS` — nunca un
  gris intermedio.

### Las skills y comandos

**3 skills cargadas en el proyecto:**

| Skill | Propósito |
|---|---|
| `sdd` (diseñada por mí) | Plantillas de spec/plan/tasks, reglas del flujo SDD, formato EARS para requisitos |
| `ruby-rails` | Convenciones Rails, patrones de modelos y controladores |
| `vercel-react-best-practices` | Buenas prácticas de React y TypeScript |

**9 comandos `/sdd-*` ajustados a este proyecto:**

| Comando | Agente | Hace |
|---|---|---|
| `/sdd-constitution` | Planner | Propone un cambio a `docs/constitution.md` (solo el usuario aprueba) |
| `/sdd-spec` | Planner | Entrevista (máx. 5 preguntas) y redacta `spec.md` |
| `/sdd-clarify` | Reviewer | QA de la spec: detecta ambigüedades y contradicciones, no las resuelve |
| `/sdd-plan` | Planner | Redacta `plan.md` desde la spec aprobada |
| `/sdd-tasks` | Planner | Redacta `tasks.md` desde el plan aprobado |
| `/sdd-implement` | Implementer | Implementa UNA tarea, tests primero, luego para |
| `/sdd-validate` | Reviewer | Validación RF por RF con evidencia real → VEREDICTO |
| `/sdd-change` | Planner | Actualiza la spec ante un cambio de requisito |
| `/sdd-status` | Coordinator | Estado actual de la spec + próximo comando |

---

## Mi rol vs. el rol de la IA

Esta es la parte más importante.

### Lo que decidí yo

**Diseñé el sistema completo.** Los 4 agentes, sus permisos, el ciclo SDD, las skills,
los 9 comandos y la constitución no los generó la IA: los diseñé yo y los ajusté al
proyecto a medida que avanzaban las specs.

**Definí los 17 principios de la constitución (`docs/constitution.md`).** Antes de
escribir una sola línea de código, establezco los principios no negociables: qué stack
usar, cómo manejar errores, dónde viven las validaciones, cuándo agregar dependencias,
cómo estructurar los commits. Si un spec, plan o línea de código contradice la
constitución, el trabajo se detiene.

**Elegí el stack tecnológico.** Rails API + PostgreSQL + React + TypeScript + Tailwind
CSS + Docker. Cada elección tiene una razón registrada en `MEMORY.md`.

**Resolví cada Open Decision antes de que la IA escribiera código.** Cuando el planner
encontraba una ambigüedad que no podía resolver solo, la escalaba como `OPEN DECISION`
en `MEMORY.md`. Yo la resolvía. Ejemplos reales:

- **D-6** — Charset del SKU: decidí que admite letras mayúsculas, dígitos e guiones
  (`ABC-123`), no solo letras y dígitos. Esto afecta tanto el modelo Rails como el
  validador del frontend (mirror rule).
- **D-10** — Sin React Query ni react-router: decidí usar `fetch` puro y una sola
  vista con modal. El planner había considerado React Query; lo rechacé por complejidad
  innecesaria (C5/C6).
- **D-15** — Actor de auditoría: decidí que el campo `actor` en `product_audits` sea
  siempre el string fijo `"system"`. Sin autenticación, no tiene sentido inventar un
  actor; el campo queda listo para un actor real si llega auth.
- **D-18** — UI de documentación: decidí vendorizar `swagger-ui-dist` (3 archivos
  estáticos commiteados) en lugar de usar CDN. Cero dependencias nuevas en `Gemfile`
  ni `package.json`, y los assets se sirven desde la propia aplicación.
- **D-20** — Proveedor de deploy: decidí usar Render (Hobby, sin tarjeta). Evalué
  Vercel (descartado: sin runtime Rails nativo y sin PostgreSQL bundled) y Railway
  (descartado: cerrado a nuevos registros en el momento de la evaluación).
- **D-21** — Servidores relativos en OpenAPI: cuando el intento de override de
  `servers` en la config de Swagger UI 5.34 fue ignorado por el cliente, decidí
  documentar la API con `servers: [{ url: "/" }]` — relativo al origen que sirve el
  documento, no hardcodeado a `localhost`.

**Aprobé cada spec y cada plan.** Ningún código se escribió sin que yo leyera y
aprobara explícitamente la especificación de lo que se iba a construir y el plan de
cómo hacerlo. En varios casos rechacé o pedí cambios:
- Planes que introducían abstracciones no pedidas por la spec.
- Specs donde el planner suponía algo que debía ser una pregunta.
- Tasks con granularidad incorrecta (demasiado grandes o fragmentadas sin razón).

**Rechacé dependencias innecesarias.** El criterio C6 de la constitución dice que una
dependencia solo entra si su beneficio justifica la complejidad añadida. Ejemplos de lo
que no entró: Kaminari/Pagy (paginación manual más simple y explicable), `audited` gem
(callbacks Rails nativos suficientes), React Query (fetch puro más directo para el
scope del reto), `paranoia` gem (soft delete con un campo `deleted_at` sin gem).

### Lo que ejecutó la IA

- Redactar specs, planes y tasks siguiendo los templates de la skill SDD.
- Implementar cada tarea (una a la vez, tests primero en rojo, luego código).
- Hacer QA de specs como reviewer: detectar ambigüedades que yo no había visto.
- Validar cada spec RF por RF con evidencia real (ejecutando los tests, no suponiendo).
- Mantener `MEMORY.md` actualizado al final de cada sesión con decisiones y lecciones.
- Reportar cuando algo era imposible o contradecía la spec, en lugar de improvisar.

---

## Recorrido por las 6 specs

| Spec | Entregó | Decisión clave mía | Tests |
|---|---|---|---|
| **001 — Backend API** | Modelo `Product`, 5 endpoints bajo `/api/v1/products`, seeds, suite RSpec | Paginación manual (`limit`/`offset`) sin gems; contrato de error único 404/422/500 | 90 ejemplos RSpec |
| **002 — Frontend UI** | React + Tailwind, modal de formulario, estados loading/error/vacío, diseño responsive, suite Vitest | Sin React Query ni react-router; `fetch` puro; `price` como string de punta a punta para no perder decimales | 57 tests Vitest + RTL |
| **003 — CI** | GitHub Actions con run-all (si falla una verificación, las otras siguen) | Mismos comandos `docker compose` en CI y en local (paridad exacta); no-TTY con `-T` en runners | — (verifica las 3 suites) |
| **004 — Integridad de datos** | Soft delete (`deleted_at`) + auditoría en `product_audits` dentro de la misma transacción | Actor fijo `"system"` sin auth; sin gems `audited`/`paranoia`; payload equivalente no genera entrada de auditoría | 124 ejemplos RSpec (+34) |
| **005 — OpenAPI** | Documento OpenAPI 3.0.3 escrito a mano + Swagger UI vendorizado + suite anti-drift que falla si el doc miente | Vendorizar `swagger-ui-dist@5.34.0` (3 archivos estáticos, sin CDN); servers relativos para funcionar en cualquier origen | 181 ejemplos RSpec (+57) |
| **006 — Deploy** | Imagen multi-stage única (Vite build + Rails) + deploy automático en Render desde `main` | Un solo proveedor para todo (Render); Render recibe `VITE_API_BASE_URL` como build arg; cold start ≤ 90 s verificado | 181 + 57 (sin regresiones) |

**Resultado final:** 181 ejemplos RSpec, 57 tests Vitest — todos en verde. Aplicación
desplegada en producción: <https://inventory-management-ab57.onrender.com>.

---

## Lo que el repositorio conserva como evidencia

El repositorio no solo tiene el código: tiene la trazabilidad completa del proceso.

| Directorio / Archivo | Qué representa |
|---|---|
| `specs/NNN/spec.md` | El QUÉ y el POR QUÉ de cada incremento — requisitos en EARS, casos límite, fuera de alcance |
| `specs/NNN/plan.md` | El CÓMO — archivos, decisiones técnicas con la alternativa descartada, estrategia de tests |
| `specs/NNN/tasks.md` | Las unidades de trabajo con su "Done when:" verificable y su estado (`[x]` = commiteado) |
| `MEMORY.md` | Log de 21 decisiones (D-1…D-21) con su razonamiento; estado del proyecto; comandos de verificación |
| `docs/constitution.md` | Los 17 principios (C1–C17) que gobernaron las 6 specs sin excepción |
| `.opencode/agents/` | Los 4 agentes con sus frontmatters de permisos explícitos |
| `.opencode/commands/` | Los 9 comandos `/sdd-*` ajustados al proyecto |
| `.opencode/skills/` | Las 3 skills: `sdd`, `ruby-rails`, `vercel-react-best-practices` |
| `AGENTS.md` | Punto de entrada del sistema: qué leer primero, reglas duras, tabla de comandos |

Cada commit del historial corresponde a exactamente una tarea de un spec (C17). El
mensaje describe qué cambió; el diff incluye implementación, tests y la actualización
de `tasks.md` — nada más y nada menos.

---

## Reflexión honesta

### Qué funcionó bien

**La separación de responsabilidades entre agentes fue muy efectiva.** El hecho de que
el implementer no pudiera tocar `specs/` ni `MEMORY.md`, y el reviewer no pudiera
editar nada, eliminó una clase entera de errores: la IA nunca "arregló" silenciosamente
una spec para que coincidiera con código incorrecto.

**El ciclo de validación RF por RF con VEREDICTO explícito fue riguroso.** En varias
specs el reviewer devolvió `VEREDICTO: CAMBIOS NECESARIOS` con una lista numerada de
lo que incumplía. Eso obligó a volver al implementer con la lista exacta — sin
interpretación libre. La spec 006 necesitó dos vueltas de corrección antes de
aprobarse.

**Tener la constitución escrita antes de empezar mantuvo la coherencia.** Las 6 specs
fueron escritas por el mismo planner en sesiones distintas, semanas aparte. La
constitución fue lo que garantizó que no se contradijesen entre sí.

**El modelo pequeño forzó diseño preciso.** MiMo-V2.6-Flash comete más errores que
modelos más grandes si el prompt es vago. Eso me obligó a ser muy explícito en los
gates de aprobación, los "Done when:" y las reglas de la constitución. El resultado fue
un sistema más robusto que si hubiera usado un modelo más capaz de "adivinar" mi
intención.

### Qué fue desafiante

**El contexto entre agentes debía pasarse explícitamente.** Los subagentes no ven la
conversación del coordinator. En cada llamada, el coordinator debía incluir la fase en
curso, las decisiones relevantes, las rutas de los archivos a leer y el resultado de la
fase anterior. Si se omitía algo, el subagente actuaba sobre información incompleta.

**Los gates de aprobación ralentizan el ritmo intencionalmente.** No es un bug del
sistema: es el diseño. Aprobar una spec mal escrita acelera el trabajo a corto plazo y
lo rompe a largo plazo. La ralentización es el precio de la coherencia.

**El planner tenía tendencia a sobrespecificar.** En varias specs el primer borrador
superaba las 150 líneas (el límite de la skill SDD). Parte de mi trabajo como
aprobador fue pedir simplificaciones: "este edge case no cambia el comportamiento
requerido, va al plan, no a la spec".

**La skill `vercel-react-best-practices` era muy extensa** (72 reglas). En la práctica
el implementer la usaba de forma selectiva; fue más útil como referencia que como guía
activa.

---

*Este documento describe el proceso real del proyecto. Los archivos referenciados
existen en el repositorio y pueden inspeccionarse directamente.*
