/**
 * plugin.ts — OpenCode V1 server entry for the saki-builder plugin.
 *
 * opencode loads a plugin package by importing its entrypoint and calling the
 * default export, which must be a function returning the hooks object (a V1
 * `PluginModule`'s `server`). We dynamically import ./safety-hooks rather than
 * statically, because opencode 1.18.x evaluates a static top-level import of
 * that module (which itself imports ./saki-state and reads import.meta.dirname)
 * in a context where it throws at module-evaluation time and takes down every
 * run with "Unexpected server error". A dynamic import defers evaluation into
 * the async server() call, where it succeeds. Do not revert to a static import.
 */
export const id = "saki-builder"

export default async () => {
  const { SafetyHooks } = await import("./safety-hooks")
  return SafetyHooks({})
}
