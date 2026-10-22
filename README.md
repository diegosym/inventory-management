# inventory-management

Retó técnico Full Stack: aplicación web de **gestión de productos (CRUD)** — Rails API
+ React. **Estado actual: repositorio preparado (constitución, flujo SDD y tooling);
la aplicación todavía no está implementada.**

## Stack acordado

| Capa | Tecnología |
|---|---|
| Backend | Ruby on Rails (modo API) + **PostgreSQL** |
| Pruebas backend | **RSpec** (obligatorio) |
| Frontend | **React + TypeScript** |
| CSS | **Tailwind CSS** |
| Ejecución | **Docker Compose** — sin instalar Ruby, PostgreSQL ni Node en el host |

Librerías adicionales (p. ej. React Query, Vitest de frontend): solo si simplifican
de verdad la implementación y queda la decisión registrada en `MEMORY.md` (C6).

## Estructura del repositorio

```
├── docs/
│   ├── constitution.md        # Constitución del proyecto (C1–C17) — reglas no negociables
│   └── Reto técnico.pdf       # Enunciado original — fuente de verdad (C2)
├── AGENTS.md                  # Contrato de sesión: cómo se trabaja en este repo
├── MEMORY.md                  # Contexto estable: stack, decisiones, comandos, OD abiertos
├── specs/                     # Artefactos SDD (spec/plan/tasks por incremento)
│   └── README.md              # Flujo SDD y roadmap de specs (001–006)
├── .opencode/                 # Comandos /sdd-*, agentes (coordinator/planner/…) y skills
├── backend/ · frontend/       # Requisito de entrega — se crean en specs 001/002
└── docker-compose.yml         # Se crea en el spec 001 (scaffolding)
```

## Flujo de trabajo (SDD)

Constitución → Spec → Clarificación → Plan → Tareas → Implementación → Validación,
con **aprobación del usuario en cada puerta**. Comandos: `/sdd-spec`, `/sdd-clarify`,
`/sdd-plan`, `/sdd-tasks`, `/sdd-implement`, `/sdd-validate`, `/sdd-change`,
`/sdd-status`, `/sdd-constitution`.

Orden de specs (ver `specs/README.md`): **core primero** — `001-backend-api` →
`002-frontend-ui` — y después los bonus en orden de complejidad: CI → soft delete +
auditoría → OpenAPI → deploy.

## Cómo se ejecuta y se testea

Aún no hay código. Tras el scaffolding del spec `001` será:

```sh
docker compose up -d --build
docker compose exec backend bundle exec rspec    # pruebas backend
docker compose run --rm frontend npm test        # pruebas frontend (si existen)
```

Los comandos exactos de verificación viven en `MEMORY.md → Development commands`.

## Decisiones técnicas

Están registradas en `MEMORY.md` (D-1 … D-6): ejecución 100% en Docker, TailwindCSS,
libs opcionales según C6, entrega iterativa core → bonus, layout `backend/` +
`frontend/`, y formato de SKU (mayúsculas + números + guiones en ambos lados).

## Mejoras futuras

Roadmap de bonus en `specs/README.md` (`003`–`006`): CI con GitHub Actions, soft
delete + auditoría de cambios, documentación OpenAPI y deploy funcional. Se
implementarán solo después de validar el alcance obligatorio (C7).
