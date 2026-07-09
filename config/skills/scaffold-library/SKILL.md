---
name: scaffold-library
description: Setup library/package project structure with source, build config, public API, and tests — polyglot (Go, Python, Rust, Node, TypeScript, Ruby)
type: scaffold
project_types: [library]
trigger: "create library, setup package, init library, scaffold gem, scaffold crate"
inputs:
  - name: name
    description: Library/package name
    required: true
  - name: language
    description: "Target language (go, python, rust, node, typescript, ruby). Default auto — detect from an existing manifest (go.mod / Cargo.toml / pyproject.toml / package.json / *.gemspec); if none (greenfield), ask which of the six."
    required: false
    default: "auto"
  - name: runtime
    description: "Node/TypeScript only — target runtime (node, browser, universal). Ignored for Go, Python, Rust, Ruby."
    required: false
    default: "universal"
  - name: format
    description: "Node/TypeScript only — output format (esm, cjs, both). Ignored for Go, Python, Rust, Ruby."
    required: false
    default: "both"
---

## Context

You will create a library "{{input.name}}".

Target language: {{input.language}} (default `auto` — detect from an existing manifest; if the directory is
greenfield with no manifest, confirm the language with the user before scaffolding).

Read AGENTS.md for conventions. If the project already has source, read existing files to match its layout,
build tool, and test framework before generating anything new — do not impose a different toolchain on an
established project.

> Node/TypeScript only: `{{input.runtime}}` (runtime) and `{{input.format}}` (output format) shape the
> dual-package build. Both are ignored for Go, Python, Rust, and Ruby.

## Instructions

1. **Detect language / analyze existing patterns**
   - Detect from manifest (see `## Script`): `go.mod`→Go · `Cargo.toml`→Rust · `pyproject.toml`/`setup.py`→Python ·
     `package.json` + `tsconfig.json`→TypeScript · `package.json` alone→Node · `*.gemspec`/`Gemfile`→Ruby.
   - If no manifest is found, use `{{input.language}}`; if that is `auto`, ask which of the six.
   - If source already exists, read it and match the existing package layout, build tool, test framework, and
     public-API style rather than introducing new ones.

2. **Setup package manifest**
   - Go: `go.mod` via `go mod init <module-path>` (module path = repo URL or `{{input.name}}`).
   - Python: `pyproject.toml` — `[build-system]` (hatchling or poetry), `[project]` name/version/description/license,
     dev extras = pytest.
   - Rust: `Cargo.toml` — `[package]` name/version/edition, `[lib]` (crate name), `[dev-dependencies]`.
   - Node: `package.json` — name, version, description, license, `main`, `exports`, `scripts`
     (build/test/lint/prepublishOnly); peerDependencies (not dependencies) for shared libs.
   - TypeScript: as Node plus `module` (ESM), `types`, and a dual `exports` map (import/require/types).
   - Ruby: `{{input.name}}.gemspec` — name/version/summary/license/files/require_paths,
     `add_development_dependency "rspec"`; `Gemfile` with `gemspec`.

3. **Setup build / packaging tool**
   - Go: none needed — libraries are consumed as modules (`go build ./...` verifies).
   - Python: `python -m build` (sdist + wheel) via hatchling/poetry.
   - Rust: `cargo build` (`--release` for release artifacts).
   - Node: tsup or unbuild (near-zero-config), source maps.
   - TypeScript: tsup for ESM + CJS output with DTS generation, per `{{input.format}}`.
   - Ruby: bundler — `gem build {{input.name}}.gemspec`.

4. **Create source structure + public API surface**
   - **Normalize `{{input.name}}` to each language's identifier rules first** — a hyphen/space in the name breaks
     a source identifier. Go: lowercase, no hyphens/underscores (`mylib`). Python/Rust crate: snake_case (`my_lib`).
     Ruby: file snake_case, module CamelCase (`my_lib.rb` → `module MyLib`). Node/TS: the package `name` may keep
     hyphens, but exported symbols must be valid identifiers. Derive the identifier from the raw name; don't inject it verbatim.
   - Go: package at repo root or `pkg/{{input.name}}/`; exported (capitalized) identifiers ARE the public API;
     `doc.go` for package docs.
     ```
     {{input.name}}.go        # package {{input.name}} — exported API
     {{input.name}}_test.go
     ```
   - Python: `src/{{input.name}}/__init__.py` re-exports the public API via `__all__`;
     `src/{{input.name}}/<module>.py`; `py.typed` marker so consumers get type hints.
   - Rust: `src/lib.rs` (crate root — `pub` items = public API, `pub mod` for submodules); `src/<module>.rs`.
   - Node: `src/index.js` (public API exports) + `src/<modules>/`.
   - TypeScript: `src/index.ts` (public API exports), `src/types.ts` (shared types), `src/<modules>/`.
   - Ruby: `lib/{{input.name}}.rb` (top-level `module <Name>` — the public API), `lib/{{input.name}}/version.rb`
     (`VERSION` constant), `lib/{{input.name}}/<module>.rb`.

5. **Setup type config** (typed languages)
   - TypeScript: `tsconfig.json` (source, strict mode) + `tsconfig.build.json` (build output, declaration files on).
   - Python: type hints + `py.typed`; optional `mypy`/`pyright` config.
   - Go / Rust: types are intrinsic — no extra config file.

6. **Setup testing**
   - Go: `{{input.name}}_test.go` with `func TestXxx(t *testing.T)`; `go test ./...`.
   - Python: pytest — `tests/test_{{input.name}}.py`; coverage via `pytest --cov`.
   - Rust: `#[cfg(test)] mod tests` in-file and/or `tests/` integration; `cargo test`.
   - Node / TypeScript: Vitest — config + example test + coverage.
   - Ruby: RSpec — `spec/spec_helper.rb`, `spec/{{input.name}}_spec.rb`; `bundle exec rspec`.

7. **Setup linting / formatting**
   - Go: `gofmt` + `go vet` (built-in); optional golangci-lint.
   - Python: ruff (lint + format), or black + flake8.
   - Rust: `cargo fmt` + `cargo clippy` (built-in toolchain).
   - Node / TypeScript: ESLint + Prettier (if not already present).
   - Ruby: RuboCop.

8. **Create README stub**
   - Installation (language-appropriate: `go get` / `pip install` / `cargo add` / `npm install` / `gem install`),
     quick start, public API reference placeholder.

9. **Setup CI** (if saki.json ci.provider != none)
   - Build + test on PR; publish on tag/release (Go proxy / PyPI / crates.io / npm / RubyGems).

## Script

```bash
#!/bin/bash
# Detect library language from its manifest, echo the toolchain to use.
if [ -f "go.mod" ]; then
  echo "Language: Go (go.mod)"
  echo "Layout: package at root or pkg/{{input.name}}/  |  Public API: exported (capitalized) identifiers"
  echo "Build: go build ./...   |  Test: go test ./..."
elif [ -f "Cargo.toml" ]; then
  echo "Language: Rust (Cargo.toml)"
  echo "Layout: src/lib.rs (pub items = public API)"
  echo "Build: cargo build   |  Test: cargo test"
  # greenfield: cargo init --lib
elif [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
  echo "Language: Python (pyproject.toml/setup.py)"
  echo "Layout: src/{{input.name}}/__init__.py (public API via __all__)"
  echo "Build: python -m build   |  Test: pytest"
elif [ -f "package.json" ]; then
  if [ -f "tsconfig.json" ] || grep -q '"typescript"' package.json 2>/dev/null; then
    echo "Language: TypeScript (package.json + tsconfig.json)"
    echo "Layout: src/index.ts (public API exports)  |  Build: tsup (ESM+CJS+DTS)"
  else
    echo "Language: Node (package.json)"
    echo "Layout: src/index.js (public API exports)  |  Build: tsup"
  fi
  echo "Test: vitest"
  # fresh Node/TS lib: npm install -D typescript tsup vitest @types/node
elif ls ./*.gemspec >/dev/null 2>&1 || [ -f "Gemfile" ]; then
  echo "Language: Ruby (gemspec/Gemfile)"
  echo "Layout: lib/{{input.name}}.rb (module = public API) + lib/{{input.name}}/version.rb"
  echo "Build: gem build {{input.name}}.gemspec   |  Test: bundle exec rspec"
else
  echo "No manifest detected (greenfield)."
  echo "Use {{input.language}}; if 'auto', ask which of: go, python, rust, node, typescript, ruby."
  echo "Init: go mod init <path> | cargo init --lib | (pyproject.toml) | npm init -y | bundle gem {{input.name}}"
fi
```

## Validation

- [ ] Build succeeds (`go build ./...` / `python -m build` / `cargo build` / `npm run build` / `gem build`)
- [ ] Tests pass (`go test ./...` / `pytest` / `cargo test` / `vitest` / `bundle exec rspec`)
- [ ] Package artifact produced (module resolves / wheel + sdist / crate / `dist/` / `.gem`)
- [ ] Public API importable from a consumer (Go `import` · Python `from {{input.name}} import ...` ·
      Rust `use {{input.name}}::...` · Node/TS ESM import + CJS require · Ruby `require "{{input.name}}"`)
- [ ] Types available where applicable (TypeScript `.d.ts` generated · Python `py.typed` present)
- [ ] Lint passes (gofmt/vet · ruff · clippy · ESLint · RuboCop)
- [ ] README documents install + quick start for the target language
