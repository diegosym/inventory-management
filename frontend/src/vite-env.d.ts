/// <reference types="vite/client" />

// Typed access to the env var the compose `frontend` service provides (NFR-2).
interface ImportMetaEnv {
  readonly VITE_API_BASE_URL: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
