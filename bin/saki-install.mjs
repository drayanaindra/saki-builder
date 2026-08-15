#!/usr/bin/env node
/**
 * saki-install.mjs — install the saki-builder opencode bundle into an opencode config dir.
 *
 * What it does (the npm-package analogue of bin/opencode-bridge.sh, without the bash toolchain):
 *   1. copies AGENTS.md, agent/, commands/, skills/ from the package's dist/opencode-bundle into
 *      the target config dir (default ~/.config/opencode) — merging, never deleting user files;
 *   2. repoints `config/docs/...` references in the installed AGENTS.md to the package's absolute
 *      path, so on-demand rule references resolve from any working directory;
 *   3. writes .saki-env pinning SAKI_PLUGIN_ROOT to the package (parity with the bridge);
 *   4. timestamp-backups ONLY real files it is about to overwrite (never whole user dirs). A
 *      symlinked managed dir (e.g. a previous bridge install) is moved aside first so writes never
 *      leak into the source repo.
 *
 * Plugin registration is deliberately NOT done here — use `opencode plugin @saketek/saki-builder
 * --global`, which merges the entry into opencode.json[c] with opencode's own parser.
 *
 * Usage:
 *   node bin/saki-install.mjs                     # install into ~/.config/opencode
 *   node bin/saki-install.mjs --target "$TMP/cfg" # install into a specific dir (testing)
 *   node bin/saki-install.mjs --dry               # print what would happen, write nothing
 */
import {
  copyFileSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  renameSync,
  statSync,
  writeFileSync,
} from "fs"
import { homedir } from "os"
import path from "path"
import { fileURLToPath } from "url"
import { detectEngine, recommendationFor } from "./engine-detect.mjs"

const HERE = path.dirname(fileURLToPath(import.meta.url))
const PKG = path.resolve(HERE, "..")

const MANAGED_DIRS = ["agent", "commands", "skills"]
const MANAGED_FILES = ["AGENTS.md"]

function args() {
  const argv = process.argv.slice(2)
  const get = (flag) => {
    const i = argv.indexOf(flag)
    if (i === -1) return undefined
    const v = argv[i + 1]
    if (!v || v.startsWith("--")) {
      console.error(`saki-install: ${flag} needs a path`)
      process.exit(1)
    }
    return v
  }
  return {
    target: get("--target") ?? path.join(homedir(), ".config", "opencode"),
    bundle: get("--bundle") ?? path.join(PKG, "dist", "opencode-bundle"),
    engine: get("--engine"),
    dry: argv.includes("--dry"),
  }
}

function ensureBundle(bundle) {
  for (const name of [...MANAGED_FILES, ...MANAGED_DIRS]) {
    if (!existsSync(path.join(bundle, name))) {
      console.error(`saki-install: bundle missing ${name} at ${bundle}`)
      console.error("  run `bash bin/build-npm-bundle.sh` (npm pack runs it via prepack)")
      process.exit(1)
    }
  }
}

function listFiles(root, rel = "") {
  const out = []
  for (const entry of readdirSync(path.join(root, rel))) {
    const child = rel ? `${rel}/${entry}` : entry
    if (statSync(path.join(root, child)).isDirectory()) out.push(...listFiles(root, child))
    else out.push(child)
  }
  return out
}

function filesDiffer(a, b) {
  if (!existsSync(b)) return true
  if (lstatSync(b).isSymbolicLink()) return true
  return !readFileSync(a).equals(readFileSync(b))
}

// Back up a single real file (or move a symlink aside) before we overwrite it.
// The backup dir is created lazily — a fully idempotent run never writes a backup.
function backupOne(backupDir, abs) {
  if (!existsSync(abs)) return
  const st = lstatSync(abs)
  const rel = path.basename(abs)
  const dest = path.join(backupDir, rel)
  mkdirSync(backupDir, { recursive: true })
  mkdirSync(path.dirname(dest), { recursive: true })
  if (st.isSymbolicLink()) {
    renameSync(abs, dest) // rename keeps the link; we replace the path with a real file below
  } else if (st.isFile()) {
    copyFileSync(abs, dest)
  }
}

// Copy a bundle subtree into target, backing up only conflicting real files.
function copyTree(src, dest, backupDir, dry) {
  const created = []
  for (const rel of listFiles(src)) {
    const from = path.join(src, rel)
    const to = path.join(dest, rel)
    if (dry) {
      if (filesDiffer(from, to)) created.push(to)
      continue
    }
    if (!filesDiffer(from, to)) continue
    mkdirSync(path.dirname(to), { recursive: true })
    backupOne(backupDir, to)
    copyFileSync(from, to)
    created.push(to)
  }
  return created
}

function repointDocsRefs(text, pkgRoot) {
  const docs = path.join(pkgRoot, "config", "docs")
  if (!existsSync(docs)) return text
  // Bare `config/docs/…` only — never one already prefixed (idempotent across re-runs).
  return text.replace(/(?<![\w/])config\/docs\//g, `${docs}/`)
}

// The exact bytes the installer wants on disk for a managed file. AGENTS.md is repointed in memory
// so a re-run compares against the installed (repointed) content — never re-writes it.
function targetContent(name) {
  const raw = readFileSync(path.join(bundle, name), "utf8")
  return name === "AGENTS.md" ? repointDocsRefs(raw, PKG) : raw
}

function matches(to, content) {
  if (!existsSync(to)) return false
  if (lstatSync(to).isSymbolicLink()) return false
  return readFileSync(to, "utf8") === content
}

const { target, bundle, dry, engine: explicitEngine } = args()
const engine = detectEngine({ explicitEngine })
const recommendation = recommendationFor(engine)
const say = (msg) => console.log(`  ${dry ? "[dry]" : "✓"} ${msg}`)
const warn = (msg) => console.log(`  ⚠ ${msg}`)

console.log(`saki-builder → ${target}`)
console.log(`  bundle : ${bundle}`)
console.log(`  pkg    : ${PKG}`)
if (!dry) mkdirSync(target, { recursive: true })
ensureBundle(bundle)

const backupDir = path.join(target, `.saki-backup-${new Date().toISOString().replace(/[:.]/g, "-")}`)

// A symlinked managed dir (previous bridge install) must become a real dir — never write through it.
for (const name of MANAGED_DIRS) {
  const abs = path.join(target, name)
  if (existsSync(abs) && lstatSync(abs).isSymbolicLink()) {
    if (dry) {
      warn(`${name}/ is a symlink — will replace with a real dir`)
      continue
    }
    mkdirSync(backupDir, { recursive: true })
    renameSync(abs, path.join(backupDir, name))
    mkdirSync(abs, { recursive: true })
    warn(`${name}/ was a symlink — replaced with a real dir (moved to ${backupDir})`)
  } else if (!dry) {
    mkdirSync(abs, { recursive: true })
  }
}

for (const name of MANAGED_FILES) {
  const to = path.join(target, name)
  const content = targetContent(name)
  if (dry) {
    if (!matches(to, content)) say(`write ${name}`)
    continue
  }
  if (matches(to, content)) {
    say(`${name}  (unchanged)`)
    continue
  }
  backupOne(backupDir, to)
  writeFileSync(to, content)
  say(`${name}`)
}

let total = 0
for (const name of MANAGED_DIRS) {
  const from = path.join(bundle, name)
  const to = path.join(target, name)
  const n = copyTree(from, to, backupDir, dry).length
  total += n
  if (dry) {
    if (n > 0) say(`${name}/  ${n} files to write`)
  } else {
    say(`${name}/  ${n} files`)
  }
}

if (!dry) {
  const envFile = path.join(target, ".saki-env")
  const env = `SAKI_PLUGIN_ROOT=${PKG}\n`
  if (!(existsSync(envFile) && readFileSync(envFile, "utf8") === env)) {
    writeFileSync(envFile, env)
    say(`.saki-env  (SAKI_PLUGIN_ROOT=${PKG})`)
  }
}

console.log("")
console.log(`Detected engine: ${recommendation.label}`)
if (recommendation.command !== undefined) {
  console.log(`Use saki-builder skills with: ${recommendation.command}`)
  console.log(`Example: ${recommendation.example}`)
} else {
  console.log("Use one of these engine-specific forms:")
  console.log("  Claude Code: /saki-builder:<skill>")
  console.log("  Codex:       $saki-builder:<skill>")
  console.log("  OpenCode:    /<skill>")
  console.log("Override detection with: --engine claude|codex|opencode")
}
console.log("")
console.log("OpenCode registration (required for safety hooks + run visibility):")
console.log("  opencode plugin @saketek/saki-builder --global")
console.log("then restart the active engine.")
