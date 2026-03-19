---
name: Rails Error Handling & Logging
description: Consistent exception handling, logging, and observability patterns in Rails.
---

## When to use
- Adding new error boundaries or rescue flows
- Introducing structured logging for services or background jobs

## Required conventions
- Log with context (`request_id`, model IDs, external request IDs)
- Prefer explicit error classes per domain
- Avoid rescuing `StandardError` without re-raising or reporting

## Examples
```ruby
begin
  service.call
rescue Payments::GatewayError => error
  Rails.logger.error("payments.gateway_error", error: error.message, order_id: order.id)
  raise
end
```

## Do / Don’t
**Do**:
- Use structured log keys for searchability
- Surface actionable messages for operators

**Don’t**:
- Swallow exceptions silently
- Log sensitive data (PII, secrets)
