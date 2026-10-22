# Inventory Management

Reto técnico Full Stack: aplicación web de **gestión de productos (CRUD)** con
listado paginado, búsqueda, filtro por estado y formulario en modal. Todo corre
con **Docker Compose** — sin instalar Ruby, PostgreSQL ni Node en el host.

## Qué es la aplicación

| Capa | Tecnología |
|---|---|
| Backend | Ruby on Rails (modo API) + PostgreSQL |
| Frontend | React + TypeScript + Tailwind CSS (Vite) |
| Pruebas | RSpec (backend) · Vitest + React Testing Library (frontend) |
| Ejecución | Docker Compose: `db` + `backend` + `frontend` |

**Funcionalidad:** listar productos (paginación de 10/página, búsqueda por
nombre, filtro activo/inactivo), crear, editar y eliminar — cada acción
destructiva o de guardado pide confirmación; validación en vivo en el formulario
con los mismos mensajes que el backend; estados de carga, error (con reintento)
y vacío; diseño responsive (tarjetas en móvil, tabla desde 768px) y operable
con teclado.

**Estructura del repositorio:**

```
├── backend/            # Rails API (spec 001): modelo Product, 5 endpoints bajo
│   │                   #   /api/v1/products, seeds y suite RSpec
│   └── spec/           # modelos, requests, seeds y smoke
├── frontend/           # React + Vite (spec 002)
│   └── src/
│       ├── api/        # capa fetch tipada (list/create/update/delete)
│       ├── validators/ # espejo exacto de las validaciones del backend
│       ├── hooks/      # useProducts, useDebouncedValue
│       ├── components/ # lista, fila/tarjeta, modal, diálogos, notificaciones
│       └── __tests__/  # suite Vitest + RTL
├── docker-compose.yml  # servicios db, backend y frontend
├── .env.example        # plantilla de variables de entorno (sin secretos)
├── docs/               # constitución (C1–C17) y enunciado original
├── specs/              # artefactos SDD: 001-backend-api, 002-frontend-ui, …
└── MEMORY.md           # decisiones, comandos y contexto estable del proyecto
```

## Cómo arrancar todo

Requisitos: Docker Desktop corriendo. Nada más (C8: todo pasa por compose).

1. **Variables de entorno** — crea `.env` desde la plantilla **solo si aún no
   existe** (si ya existe, NO lo sobrescribas: su `POSTGRES_PASSWORD` es el que
   autentica contra el volumen de datos existente):

   ```sh
   cp .env.example .env   # solo si .env no existe todavía
   ```

2. **Levantar los tres servicios:**

   ```sh
   docker compose up -d --build
   ```

3. **Sembrar datos de desarrollo** (opcional, la primera vez):

   ```sh
   docker compose exec backend bin/rails db:prepare db:seed
   ```

 URLs tras el arranque:

 - **UI:** <http://localhost:5173> (dev server de Vite)
 - **API:** <http://localhost:3000/api/v1/products>

 Para parar todo: `docker compose down` (los datos persisten en el volumen
 `db_data`).

## Cómo ejecutar los tests

```sh
# backend (RSpec, obligatorio)
docker compose exec backend bundle exec rspec

# frontend (Vitest + React Testing Library, no-watch)
docker compose run --rm frontend npm test

# frontend: typecheck (tsc -b) + build de producción
docker compose exec frontend npm run build
```

Los comandos exactos de verificación viven en `MEMORY.md → Development
commands`; todo se ejecuta vía compose, nunca Node ni Ruby en el host.

## API (resumen)

Base: `http://localhost:3000` · prefijo `/api/v1` · recurso único: `products`.
Las respuestas de éxito usan envelope `{ "data": … }`; el listado añade
`meta`:

| Método y ruta | Éxito | Cuerpo de petición |
|---|---|---|
| `GET /api/v1/products?page&q&active` | 200 `{ data: [ … ], meta }` | — (`page` entero positivo; `active` = `"true"`/`"false"`; `q` busca por nombre, case-insensitive) |
| `GET /api/v1/products/:id` | 200 `{ data: { … } }` | — (id inexistente o no numérico → 404) |
| `POST /api/v1/products` | 201 `{ data: { … } }` | `{ "product": { name, description, price, stock, sku, active } }` |
| `PUT /api/v1/products/:id` | 200 `{ data: { … } }` | ídem (reemplazo completo; `active` omitido conserva su valor) |
| `DELETE /api/v1/products/:id` | 204 sin cuerpo | — |

- `meta` = `{ current_page, total_count, total_pages }`; 10 productos por
  página, orden `created_at DESC, id DESC`; una página fuera de rango responde
  200 con `data` vacío.
- El producto se serializa con `price` como **string de 2 decimales**
  (`"49.99"`) y `active` como boolean JSON.
- Contrato de errores único — `{ "error": { "code", "message", "details" } }`:
  **404** `not_found` ("Product not found"), **422** `validation_failed`
  ("Validation failed", con `details` por campo — solo en 422) y **500**
  `internal_error` ("Internal server error", sin filtrar detalles internos).
  Los parámetros de listado malformados también responden 422 con `details`
  por parámetro.

## Decisiones Técnicas

Fuente completa: `MEMORY.md` (D-1…D-12) y los planes de `specs/001` y
`specs/002` (D-P*). Las esenciales:

- **100% Docker (D-1):** compose levanta `db` + `backend` + `frontend`; el host
  no necesita Ruby, PostgreSQL ni Node. Descartado instalar toolchains con brew.
- **Tailwind CSS (D-2)** como framework CSS — el más ligero de integrar con
  Vite; tokens de diseño en el bloque `@theme` de Tailwind v4 (D-P20), sin
  sistema CSS paralelo.
- **Layout `backend/` + `frontend/` (D-5)** con compose en la raíz: requisito
  de entrega del reto.
- **SKU (D-6):** obligatorio y único; se normaliza a mayúsculas y solo admite
  `A-Z`, `0-9` y guiones (`abc-123` → `ABC-123`); respaldado por índice único
  en PostgreSQL y replicado en el frontend (regla espejo, C14).
- **Contrato de API congelado (D-7/D-9):** envelope `{ data, meta }`, errores
  `{ error: { code, message, details } }`, `price` como string decimal,
  bodies envueltos en `{ "product": … }` (D-P10), `active` como boolean JSON,
  CORS restringido a `/api/v1/*` con `FRONTEND_ORIGIN`.
- **Sin gems de paginación (D-P3):** `limit`/`offset` + `count` a mano en el
  controlador; búsqueda y filtro resueltos en PostgreSQL (C11).
- **Validaciones en el modelo (C9)** y sus mensajes literales son la fuente de
  verdad; el frontend los copia exactamente (C14/D-12): `"is not a number"`
  para `price`/`stock` vacíos, `"must have at most 2 decimal places"` para
  `price`, etc.
- **Sin React Query ni react-router (D-10/D-P15):** `fetch` puro, un hook
  `useProducts` con debounce de ~300 ms, y una sola vista con modal (C6).
- **Vitest + React Testing Library + jsdom (D-10/D-P22)** con `fetch`
  stubbeado; sin MSW ni librerías de componentes (C6).
- **`price`/`stock` como strings de punta a punta en el formulario (D-P17):**
  inputs de texto con `inputMode="decimal"`; nada convierte el precio a
  `number` de JS, así `"49.99"` sobrevive el ciclo editar→guardar sin artefactos
  binarios.
- **URL del API por env (D-P14/D-11):** `VITE_API_BASE_URL` (por defecto
  `http://localhost:3000`, el puerto mapeado al host — el navegador no resuelve
  `http://backend:3000`); el origen del dev server (5173) queda fijado en
  `vite.config.ts` y coincide con el CORS por defecto del backend (D-9).
- **Un solo diálogo de confirmación (D-P19)** reutilizado para guardar y
  eliminar; notificaciones persistentes hasta descartarlas — deterministas y
  testeables.
- **Responsive por CSS puro (D-P21):** tarjetas por debajo de 768px y tabla a
  partir de ahí, con show/hide CSS; sin detección de viewport en JS.
- **Entrega iterativa (D-4):** core (specs 001–002) primero; los bonus se
  abordan después y por separado.

## Mejoras Futuras

Roadmap de bonus (`specs/README.md`), pendientes y entregables por separado:

- **003 — CI:** GitHub Actions ejecutando RSpec, la suite frontend y el build.
- **004 — Integridad de datos:** soft delete + auditoría de cambios.
- **005 — OpenAPI:** documentación automática de la API.
- **006 — Deploy:** despliegue funcional (el proveedor es una decisión abierta,
  OD-3).

Limitaciones conocidas (alcance actual, no bugs):

- **Sin autenticación** — fuera de alcance por el enunciado; la auditoría de
  "quién" queda como decisión abierta (OD-2, spec 004).
- **Paginación fija de 10 por página** — sin parámetro `per_page`.
- **El frontend se sirve con el dev server de Vite** (HMR incluido); no hay
  build de producción ni servidor estático — eso llega con el spec 006.
- **Sin caché de cliente ni modo offline** — cada interacción va al servidor.
- **Sin i18n ni dark mode.**
