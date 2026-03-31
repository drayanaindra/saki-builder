# Modular Architecture — Growth-Driven Pattern Reference

Import this in any project's CLAUDE.md:
```
@~/.claude/docs/modular-architecture.md
```

## Core Principle

**Group by what changes together, not by what looks similar.**

"All models in `models/`" is grouping by similarity.
"Agent model + agent routes + agent service in `modules/agents/`" is grouping by change.

---

## Architecture Ladder

Projects evolve through 4 stages. Never start at Stage 3+. Transition only when triggers fire.

### Stage 1: Flat Layered

**When:** Project start, <10 models, <15 components, 1-2 devs

```
# Backend (Python/FastAPI)          # Frontend (React/TS)
src/                                src/
├── models/                         ├── components/
├── schemas/                        ├── lib/
├── api/                            ├── hooks/
├── core/                           ├── contexts/
├── main.py                         └── App.tsx
└── config.py
```

**Rules:**
- One file per model, one file per route group
- Schemas mirror models
- `core/` for shared services
- `lib/` for API client + types
- Simple, fast, no ceremony

---

### Stage 2: Modular Monolith

**When:** Stage 1 triggers fire (see Transition Triggers below)

```
# Backend                           # Frontend
src/                                src/
├── modules/                        ├── features/
│   ├── {domain}/                   │   ├── {domain}/
│   │   ├── models.py               │   │   ├── components/
│   │   ├── schemas.py              │   │   │   ├── List.tsx
│   │   ├── routes.py               │   │   │   ├── Form.tsx
│   │   ├── service.py              │   │   │   └── Detail.tsx
│   │   └── __init__.py             │   │   ├── api.ts
│   ├── {domain2}/                  │   │   ├── types.ts
│   └── ...                         │   │   ├── hooks.ts
├── shared/                         │   │   └── index.ts
│   ├── database.py                 │   └── {domain2}/
│   ├── auth.py                     ├── shared/
│   ├── middleware.py               │   ├── api/      (fetch wrapper, auth)
│   └── {infra}/                    │   ├── types/    (cross-feature types)
├── main.py                         │   ├── hooks/    (useAuth, useDebounce)
└── config.py                       │   └── utils/
                                    ├── design-system/
                                    │   ├── tokens.css
                                    │   ├── components/ (primitives)
                                    │   └── index.ts
                                    ├── pages/
                                    ├── contexts/
                                    └── App.tsx
```

**Rules:**
- Each module/feature owns its models, schemas, routes, service, types
- Cross-module communication via service calls (backend) or shared types (frontend)
- `shared/` = infrastructure only, no business logic
- Design system = primitives + composites (extract at 3+ uses)
- Features import from `design-system/` and `shared/`, never from each other

**Module `service.py` pattern (backend):**
```python
# modules/knowledge/service.py
from .models import KnowledgeBase, Document
from .schemas import KnowledgeBaseCreate, DocumentResponse

class KnowledgeService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_kb(self, tenant_id: str, data: KnowledgeBaseCreate) -> KnowledgeBase:
        # Business logic here, not in routes
        kb = KnowledgeBase(tenant_id=tenant_id, **data.model_dump())
        self.db.add(kb)
        await self.db.commit()
        return kb
```

**Feature `api.ts` pattern (frontend):**
```typescript
// features/knowledge/api.ts
import { apiFetch } from '@/shared/api/client';
import type { KnowledgeBase, KnowledgeBaseCreate } from './types';

export async function createKnowledgeBase(data: KnowledgeBaseCreate): Promise<KnowledgeBase> {
  return apiFetch('/knowledge', { method: 'POST', body: data });
}
```

---

### Stage 3: Domain-Driven Design (per-module upgrade)

**When:** Stage 2 triggers fire for a SPECIFIC module (not all at once)

```
# Upgrade ONE module to DDD layers
src/modules/{complex-domain}/
├── domain/
│   ├── entities/
│   ├── value_objects/
│   ├── events/
│   ├── services/
│   └── repositories/    (interfaces only)
├── application/
│   ├── services/        (use cases)
│   ├── commands/
│   ├── queries/
│   └── dtos/
├── infrastructure/
│   ├── persistence/
│   │   ├── models/      (ORM)
│   │   └── repositories/ (implementations)
│   └── external/
└── interface/
    ├── routes/
    └── schemas/
```

**Rules:**
- Domain layer has ZERO external dependencies
- Infrastructure implements domain interfaces (Dependency Inversion)
- Domain events for cross-module async communication
- Only upgrade modules that genuinely need it — most stay at Stage 2

---

### Stage 4: Microservices (extract from monolith)

**When:** Stage 3 triggers fire — independent deploy/scale needed

- Extract one module at a time into its own service
- Use API gateway or message broker for communication
- Frontend: module federation or micro-frontends
- **Never start here** — always extract from a working monolith

---

## Transition Triggers

### Stage 1 → Stage 2 (Flat → Modular)

Fire when ANY of:

| Metric | Threshold | How to Check |
|--------|-----------|--------------|
| Model count | >15 models | `grep -r "class.*Base\)" models/ \| wc -l` |
| Component count | >20 components | `ls src/components/*.tsx \| wc -l` |
| File size (backend) | Any .py >300 lines | `find src -name "*.py" \| xargs wc -l \| sort -n` |
| File size (frontend) | Any .tsx >500 lines | `find src -name "*.tsx" \| xargs wc -l \| sort -n` |
| Monolith types file | >2000 lines | `wc -l lib/api.ts` or equivalent |
| Dev count | >3 devs | Team size |
| Merge conflicts | Same file conflicts 3+ times/month | Git history |

### Stage 2 → Stage 3 (Modular → DDD, per-module)

Fire when ANY of these apply to a SPECIFIC module:

| Metric | Threshold |
|--------|-----------|
| Business rules | >10 non-validation rules in the module |
| Module service.py | >500 lines of business logic |
| Cross-module coupling | Module imports 5+ other modules |
| Domain complexity | Aggregate boundaries needed (e.g., Order → OrderItems → Payment) |
| Team ownership | Dedicated team for this module |

### Stage 3 → Stage 4 (DDD → Microservices)

Fire when ANY of:

| Metric | Threshold |
|--------|-----------|
| Deploy independence | Module needs different release cadence |
| Scale independence | Module needs different scaling (CPU vs memory) |
| Tech stack | Module would benefit from different language/framework |
| Team count | >15 devs, teams blocked on shared deploys |
| Fault isolation | Module failure shouldn't take down entire app |

---

## Migration Recipe: Strangler Fig

For ANY stage transition, use this incremental approach:

```
Step 1: CREATE new structure alongside old
  old/models/agent.py          ← still works, unchanged
  new/modules/agents/models.py ← re-exports from old

Step 2: MOVE code into new structure
  modules/agents/models.py     ← owns the code now
  models/agent.py              ← re-exports from new (backward compat)

Step 3: UPDATE imports across codebase
  Change: from models.agent import Agent
  To:     from modules.agents.models import Agent

Step 4: DELETE old file when zero imports remain
  Remove models/agent.py
```

**Rules:**
- Move ONE module/feature at a time
- Verify nothing breaks after each move (run tests)
- Re-exports ensure zero breaking changes during transition
- Delete old files only when `grep` confirms zero remaining imports

### Backend re-export bridge:
```python
# old: models/agent.py (during transition)
from modules.agents.models import Agent, AgentConfig  # noqa: F401 — bridge
```

### Frontend re-export bridge:
```typescript
// old: lib/api.ts (during transition, for moved types)
export type { Agent, AgentConfig } from '@/features/agents/types';
```

---

## Design System Layers

Applicable at Stage 2+. Build bottom-up, extract (don't speculate).

```
Layer 1: TOKENS (start here)
  Colors, spacing, typography, shadows, radii
  → CSS custom properties or Tailwind config

Layer 2: PRIMITIVES (build early)
  Button, Input, Select, Toggle, Badge, Spinner, Modal
  → Stateless, styled with tokens, no business logic
  → Build when first needed

Layer 3: COMPOSITES (extract at 3+ uses)
  DataTable, FormField, SearchBar, EmptyState, ConfirmDialog
  → Composed from primitives
  → ONLY extract when you see the same pattern 3+ times

Layer 4: LAYOUTS (extract at 2+ uses)
  PageLayout, SidebarLayout, TabLayout, SplitView
  → Page-level structure
  → Extract when 2+ pages share the same skeleton
```

**Anti-pattern:** Don't build Layer 3-4 speculatively. Wait for real duplication.

---

## CI Tripwire (Optional)

Add to CI or pre-commit to get early warnings:

```bash
#!/bin/bash
# arch-check.sh — warns when you're outgrowing your stage
WARN=0

# Backend: Python files over 300 lines
while IFS= read -r file; do
  lines=$(wc -l < "$file")
  if [ "$lines" -gt 300 ]; then
    echo "⚠ $file: $lines lines (consider splitting)"
    WARN=1
  fi
done < <(find src -name "*.py" -not -path "*/migrations/*")

# Frontend: TSX files over 500 lines
while IFS= read -r file; do
  lines=$(wc -l < "$file")
  if [ "$lines" -gt 500 ]; then
    echo "⚠ $file: $lines lines (consider splitting into feature/)"
    WARN=1
  fi
done < <(find src -name "*.tsx")

exit 0  # warn only, don't block
```

---

## Quick Decision Matrix

| Question | Answer |
|----------|--------|
| "Should I use DDD?" | Not unless a specific module has >10 business rules |
| "Should I use microservices?" | Not unless you need independent deployment |
| "Should I split this file?" | Yes if >300 lines (py) or >500 lines (tsx) |
| "Should I create a shared component?" | Only if used 3+ times across features |
| "Should I add Redux/Zustand?" | Only if prop drilling >3 levels deep across features |
| "Where do cross-feature types go?" | `shared/types/` |
| "Where do DB/auth/middleware go?" | `shared/` (backend) or `shared/` (frontend) |
| "Can features import each other?" | No. Go through `shared/` or lift the shared type up |
