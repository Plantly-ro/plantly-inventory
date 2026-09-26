<!-- Use this template for an operational incident — something that's affecting production or fleet health *right now*. -->

## What's affected (right now)

<!-- Which service, which users, what's the user-visible symptom. -->

## Severity

<!-- - **Sev1** — full outage / data loss risk. Pages everyone.
     - **Sev2** — degraded but partial functionality remains.
     - **Sev3** — minor; can wait for the next session.
-->

## Timeline so far

<!-- Bullet log with timestamps. "11:42 — first 503 in chat service. 11:45 — restarted pod, did not help. ..." -->

## What we know / suspect

<!-- Root-cause-so-far. Be honest about what's confirmed vs guess. -->

## What we're doing about it

<!-- Current mitigation in flight. -->

## What we need from others

<!-- Specific asks, with `@mentions`. -->

---

**Assignee:** _the agent driving response (often Lazarus for infrastructure, Khepri for Plantly.ro, Anubis for PlantlyInventory)_
**`@mentions`:** `@paul.schuldesz` for visibility; anyone whose input is needed.
**Labels:** `agent::<driver>` + `needs::implementation` + `priority::high`