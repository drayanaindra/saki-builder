/**
 * plugin.ts — OpenCode server entry for the saki-builder plugin.
 *
 * ── EVERY EXPORT OF THIS MODULE MUST BE A PLUGIN FACTORY ────────────────────────────────────────
 * opencode 1.18.x does not look for a specific export name — it calls EVERY export of the module as
 * a plugin factory. Probed against 1.18.15, on both load paths (a file in
 * `~/.config/opencode/plugins/` and an npm package registered via `plugin: [...]` → `exports`):
 *
 *   export default fn                       → loads
 *   export const server = fn                → loads
 *   export default fn + export const x = fn → BOTH load (registered twice)
 *   export default fn + export const id = "saki-builder"  → NOTHING LOADS
 *   export default fn + export const n = 42               → NOTHING LOADS
 *
 * A non-callable export makes opencode throw while registering and skip the whole module, silently.
 * `export const id = "saki-builder"` therefore made this entire plugin inert — no safety gates, no
 * run visibility — while looking correct in review and in the `PluginModule` type (whose optional
 * `id` field belongs to the in-progress V2 system, not the V1 loader we run on).
 *
 * So: do NOT add a named export here, not even a constant, unless it is itself a plugin factory you
 * intend to register a second time. test/opencode-plugin-smoke.mts asserts this.
 *
 * ── DYNAMIC IMPORT IS ALSO LOAD-BEARING ─────────────────────────────────────────────────────────
 * We dynamically import ./safety-hooks rather than statically, because opencode 1.18.x evaluates a
 * static top-level import of that module (which itself imports ./saki-state and reads
 * import.meta.dirname) in a context where it throws at module-evaluation time and takes down every
 * run with "Unexpected server error". A dynamic import defers evaluation into the async factory
 * call, where it succeeds. Do not revert to a static import.
 */
import type { Plugin } from "@opencode-ai/plugin"

const plugin: Plugin = async (input, options) => {
  const { SafetyHooks } = await import("./safety-hooks")
  // Forward the real PluginInput. Passing `{}` here discarded `worktree`/`directory` (so run-state
  // was written relative to process.cwd() instead of the worktree) and `client` (so the bounded
  // session.idle re-prompt could never fire).
  return SafetyHooks(input, options)
}

export default plugin
