# DDD Engineering Thinking

## Mental Model

Before writing ANY code, identify:
1. **Which Bounded Context?** — Name it. If new, declare it explicitly.
2. **Which Layer?** — Domain / Application / Infrastructure / Interface
3. **Which DDD Building Block?** — Entity, Value Object, Aggregate, Repository, Domain Service, Application Service, Domain Event, Factory, Specification

## Layer Rules (BLOCKING)

### Domain Layer (innermost — zero dependencies)
- Contains: Entities, Value Objects, Aggregates, Domain Events, Repository interfaces, Domain Services, Specifications
- NEVER imports from: Infrastructure, Application, Interface layers
- NEVER imports: ORM, HTTP, framework, external libs
- Rich behavior: logic lives ON the domain objects, not in services
- Validate invariants in constructors and methods, not externally
- Exceptions are domain-specific (e.g., `InsufficientFundsError`, not `ValueError`)

### Application Layer (orchestration)
- Contains: Application Services (use cases), Command/Query handlers, DTOs
- CAN import: Domain layer only
- NEVER imports: Infrastructure, Interface layers
- Thin orchestration: coordinates domain objects, no business logic here
- One public method per use case (Single Responsibility)
- Transaction boundaries live here

### Infrastructure Layer (adapters)
- Contains: Repository implementations, ORM models, API clients, message brokers, caching
- CAN import: Domain layer (implements its interfaces), Application layer
- Maps between domain objects and persistence/external formats
- All framework-specific code lives here
- Implements interfaces defined in Domain layer

### Interface Layer (entry points)
- Contains: API routes/controllers, CLI handlers, event consumers, serializers
- CAN import: Application layer (calls use cases), Domain (for types only)
- Translates HTTP/CLI/events into application commands/queries
- Handles auth, input format validation (not business rules)
- Never contains business logic

## Dependency Rule (STRICT)

```
Interface → Application → Domain ← Infrastructure
                            ↑
                    (implements interfaces)
```

Inner layers NEVER know about outer layers. Infrastructure points inward.

## Code Generation Rules

### Entities
- Have identity (id field), equality by id
- Mutable, lifecycle-aware
- Encapsulate behavior: `order.add_item(item)` not `order.items.append(item)`
- Validate invariants: raise domain exceptions, never return error codes
- Guard clauses in constructor — invalid state is impossible

### Value Objects
- Immutable, no identity, equality by value
- Self-validating: `Email("bad")` raises, never creates invalid state
- Python: `@dataclass(frozen=True)` or custom `__eq__`/`__hash__`
- TypeScript: `readonly` properties + private constructor + static `create()` factory

### Aggregates
- Cluster of entities with one Aggregate Root
- External code ONLY references the root, never internal entities
- Transactional boundary: save/load the whole aggregate atomically
- Keep small — prefer eventual consistency over large aggregates
- Other aggregates referenced by ID, not by object reference

### Repository Pattern
- Interface in Domain layer: `class OrderRepository(ABC)`
- Implementation in Infrastructure: `class SQLAlchemyOrderRepository(OrderRepository)`
- Returns domain objects, NEVER ORM models or raw dicts
- Methods named by domain intent: `find_by_id`, `save`, `find_active_by_customer`
- No generic CRUD — repositories speak the Ubiquitous Language

### Domain Events
- Past tense naming: `OrderPlaced`, `PaymentReceived`, `ItemShipped`
- Immutable data carriers (frozen dataclass / readonly)
- Published by aggregates after state changes
- Handled by application services or event handlers
- Enable loose coupling between bounded contexts

### Domain Services
- Operations that don't naturally belong to a single Entity/VO
- Stateless — all state comes from parameters
- Named with verbs: `TransferFundsService`, `PricingCalculator`
- Use sparingly — prefer putting logic on entities first

### Application Services (Use Cases)
- Named by intent: `PlaceOrderUseCase`, `CancelBookingService`
- Inject repository interfaces via constructor (Dependency Injection)
- Pattern: load aggregate → call domain method → save → publish events
- Return DTOs to interface layer, never domain objects
- Handle cross-cutting: logging, transaction management, authorization checks

### Specifications (query predicates)
- Encapsulate query logic as composable objects
- `ActiveOrderSpec`, `HighValueCustomerSpec`
- Can be combined: `spec1 & spec2`, `spec1 | spec2`
- Passed to repositories: `repo.find_matching(spec)`

## Anti-Patterns to REJECT

| Anti-Pattern | DDD Correct |
|-------------|-------------|
| Anemic Domain Model (getters/setters only) | Rich model with behavior |
| Business logic in controller/route | Logic in domain objects |
| ORM entity IS domain entity | Separate domain model + infrastructure mapping |
| Repository returns ORM models | Repository returns domain objects |
| God service with all logic | Small focused domain services + rich entities |
| Primitive obsession (`str` for email) | Value Objects (`Email`, `Money`, `Address`) |
| Direct cross-context calls | Events or Anti-Corruption Layer |
| Large aggregate (User has everything) | Small aggregates, eventual consistency |
| Shared database between contexts | Each context owns its data |
| Framework in domain layer | Domain layer is framework-free |

## Ubiquitous Language

- Use the same terms in code as the domain experts use
- Class names, method names, variable names = domain terms
- If the domain says "Place an Order" → `order.place()`, not `order.set_status("placed")`
- Glossary belongs in the bounded context's documentation

## Checklist Before Writing Code

- [ ] Bounded Context identified and named
- [ ] Layer identified (Domain/Application/Infrastructure/Interface)
- [ ] Building block type chosen (Entity/VO/Aggregate/Service/etc.)
- [ ] No outward dependencies from inner layers
- [ ] Domain objects have behavior, not just data
- [ ] Repository interfaces in domain, implementations in infrastructure
- [ ] Ubiquitous Language used in naming
- [ ] Invariants enforced in domain objects (not externally)
