---
name: Rails Service Patterns
description: Consistent service object structure, orchestration, and transaction boundaries.
---

## When to use
- Non-trivial business logic
- Orchestrating multiple models or external calls

## Required conventions
- Service classes under `app/services`
- Single public `call` method
- Validate inputs at initialization

## Do / Don’t
**Do**:
- Return structured results (`success`, `value`, `error`)
- Keep side effects explicit

**Don’t**:
- Hide logic in callbacks
- Mix HTTP concerns into models
