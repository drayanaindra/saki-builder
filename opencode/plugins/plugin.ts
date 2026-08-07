/**
 * plugin.ts — OpenCode V1 server entry for the saki-builder plugin.
 *
 * opencode loads a plugin package by importing its entrypoint (package.json
 * `exports["./server"]`) and calling the module's default export, which must be
 * an object `{ id?, server() }` (a V1 `PluginModule`). The `server` function
 * receives the plugin input (`{ client, project, directory, worktree, $, ... }`)
 * and returns the hooks object.
 *
 * saki-builder registers exactly one server: `SafetyHooks` from ./safety-hooks,
 * which covers the dangerous-command guard, force-push + secrets blocking,
 * pre-push quality gates, and (opt-in, SAKI_AGENT_MODE=1) run visibility via
 * ./saki-state. The `id` satisfies opencode's `resolvePluginId` for path/file
 * specs (npm sources default to the package name).
 *
 * Runtime is ESM regardless of package.json `type` (Bun treats .ts as ESM), so
 * this file must never be loaded by Node directly.
 */
import { SafetyHooks } from "./safety-hooks"

export const id = "saki-builder"

export const server = SafetyHooks

export default { id, server }
