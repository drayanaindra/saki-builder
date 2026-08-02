---
---

# Go Engineer

**Process:** Understand → Design → Implement → Test → Review

## Go-Specific Workflow

### Before ANY Change
1. **Read files** - Read all related `.go` files, understand interfaces and types
2. **Check interfaces** - Verify what interfaces the type must satisfy
3. **Check imports** - Ensure packages exist and are imported correctly
4. **Follow patterns** - Match existing code style in the package

### Implementation Rules
- **Error handling**: Always wrap errors with context: `fmt.Errorf("doing X: %w", err)`
- **Naming**: Follow Go conventions - exported names are PascalCase, unexported are camelCase
- **Receivers**: Use short receiver names consistent with the file (`s`, `r`, `m`, `c`)
- **Interfaces**: Define where consumed, keep small (1-3 methods preferred)
- **Context**: Thread `context.Context` as first parameter in async operations
- **Concurrency**: Use `sync.RWMutex` for shared state, never expose unlocked maps
- **Imports**: Group as stdlib | external | internal, separated by blank lines
- **Zero values**: Leverage zero values, don't initialize to defaults unnecessarily

### Testing
- Test files: `*_test.go` in same package
- Use table-driven tests for multiple cases
- Test command: `go test ./... -v -race -count=1`
- Use `t.Helper()` in test helpers
- Prefer `testing` stdlib over assertion libraries

### Build & Verify
```bash
go build ./...              # Compile check
go vet ./...                # Static analysis
go test ./... -race         # Tests with race detector
golangci-lint run ./...     # Linting (if available)
```

### Common Anti-Patterns to Avoid
| Anti-Pattern | Correct Approach |
|---|---|
| Naked returns in long functions | Use named returns only for short functions |
| `panic()` in library code | Return errors |
| `init()` with side effects | Use explicit initialization |
| Interface pollution | Small interfaces, define at consumer |
| Ignoring errors with `_` | Handle or explicitly document why ignored |
| Global mutable state | Pass dependencies explicitly |

### Quick Reference

#### Adding a New Package
1. Create `internal/<pkg>/` directory
2. Add main type + constructor
3. Define interface if consumed by other packages
4. Add tests

#### Adding a CLI Command (Cobra)
1. Create `internal/cli/<cmd>_cmd.go`
2. Define `cobra.Command` with Use, Short, RunE
3. Register in `root.go` init or Execute function
4. Add flags with proper defaults

#### Adding an Interface Implementation
1. Read the interface definition
2. Create implementing struct with required fields
3. Implement all methods with proper error handling
4. Verify: `var _ InterfaceName = (*StructName)(nil)`
