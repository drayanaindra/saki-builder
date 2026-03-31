# DDD Code Patterns Reference

Import this file in any project's CLAUDE.md to enable DDD-structured code generation:
```
@~/.claude/docs/ddd-patterns.md
```

Then customize the Bounded Contexts table and directory mapping for your project.

## Architecture: Domain-Driven Design

All code follows DDD layered architecture. Use the `DDD-Engineer` role/skill for implementation.

### Layer Dependency Rule

```
Interface → Application → Domain ← Infrastructure
```

- Domain layer has ZERO external dependencies
- Infrastructure implements Domain interfaces (Dependency Inversion)
- Application orchestrates Domain objects
- Interface translates external requests to Application commands

### Directory Structure (Python)

```
src/{bounded_context}/
  domain/
    entities/          # Entities and Aggregate Roots
    value_objects/     # Value Objects (immutable, self-validating)
    events/            # Domain Events (past tense, immutable)
    services/          # Domain Services (stateless operations)
    repositories/      # Repository interfaces (ABC)
    specifications/    # Query predicates (composable)
    exceptions/        # Domain-specific exceptions
  application/
    services/          # Use cases / Application services
    commands/          # Command objects (write intent)
    queries/           # Query objects (read intent)
    dtos/              # Data Transfer Objects (in/out)
    event_handlers/    # Cross-context event handlers
  infrastructure/
    persistence/
      models/          # ORM models (SQLAlchemy, etc.)
      repositories/    # Repository implementations
      mappers/         # Domain <-> ORM mapping
    external/          # API clients, message brokers
    config/            # Infrastructure configuration
  interface/
    api/
      routes/          # HTTP endpoints
      schemas/         # Request/response serialization
      middleware/       # Auth, rate limiting
    cli/               # CLI commands
    events/            # Event consumers (webhooks, queues)
```

### Directory Structure (TypeScript)

```
src/{bounded-context}/
  domain/
    entities/
    value-objects/
    events/
    services/
    repositories/      # Interface definitions (abstract classes / types)
    specifications/
    exceptions/
  application/
    use-cases/
    commands/
    queries/
    dtos/
    event-handlers/
  infrastructure/
    persistence/
      models/
      repositories/    # Concrete implementations
      mappers/
    external/
    config/
  interface/
    controllers/
    schemas/
    middleware/
```

### Bounded Contexts (customize per project)

| Context | Package/Directory | Description |
|---------|-------------------|-------------|
| _example_ | `src/ordering/` | _Order lifecycle management_ |
| _example_ | `src/catalog/` | _Product catalog and search_ |

> Replace the examples above with your actual bounded contexts.

### Cross-Context Communication

- Contexts communicate via **Domain Events**, not direct imports
- If synchronous call needed, use **Anti-Corruption Layer** (ACL)
- ACL translates external context's language to your context's language
- Never share domain models between contexts — each owns its definitions

### Role Sequence for DDD Tasks

| Task | Roles |
|------|-------|
| New Bounded Context | DDD-Architect → DDD-Engineer → Reviewer |
| New Entity/Aggregate | DDD-Engineer → Reviewer |
| New Use Case | DDD-Engineer → Reviewer |
| Cross-Context Feature | DDD-Architect → DDD-Engineer → Reviewer |
| Refactor to DDD | Architect → DDD-Engineer → Reviewer → QA |
