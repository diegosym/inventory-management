// Vitest setup file (RF-14 harness, jsdom + globals in vite.config.ts).
// jest-dom matchers are registered here (D-P22 test stack); RTL's auto-cleanup
// registers itself through the global `afterEach` provided by `globals: true`.
import '@testing-library/jest-dom/vitest'
