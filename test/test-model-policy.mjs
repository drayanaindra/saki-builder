#!/usr/bin/env node
import assert from "node:assert/strict"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8")

const policy = read("config/docs/model-policy.md")
assert.match(policy, /model_requirement: frontier/)
assert.match(policy, /capability contract, not a model identifier/i)
assert.match(policy, /Never rewrite `~\/\.claude\/settings\.json` from a skill/i)

const requirementSources = [
  "config/skills/prd/SKILL.md",
  "config/skills/rplan/SKILL.md",
  "config/skills/approved/SKILL.md",
  "config/antigravity-skills/build.md",
  "config/antigravity-skills/approved.md",
]
for (const relative of requirementSources) {
  assert.match(read(relative), /model_requirement:\s*frontier/, `${relative} must declare frontier`)
}

function markdownFiles(relative) {
  const absolute = path.join(root, relative)
  if (!fs.existsSync(absolute)) return []
  const entries = fs.readdirSync(absolute, { withFileTypes: true })
  return entries.flatMap((entry) => {
    const child = path.join(relative, entry.name)
    if (entry.isDirectory()) return markdownFiles(child)
    return entry.name.endsWith(".md") ? [child] : []
  })
}

const runtimeSources = [
  ...new Set([
    ...requirementSources,
    ...markdownFiles("config/skills"),
    ...markdownFiles("config/antigravity-skills"),
    ...markdownFiles("opencode/commands"),
    ...markdownFiles("opencode/agent"),
    "README.md",
  ]),
]
const vendorModel = /\b(?:opus|sonnet|haiku)\b|claude-\d|anthropic\//i
for (const relative of runtimeSources) {
  assert.doesNotMatch(read(relative), vendorModel, `${relative} contains a vendor-specific model name`)
}

const opencodeConfig = JSON.parse(read("opencode/opencode.json"))
assert.equal(opencodeConfig.model, undefined, "OpenCode must not inherit a Claude model alias")

console.log(`model policy OK (${runtimeSources.length} runtime sources checked)`)
