# AGENTS.md

## Behavior-First UI Refactor Protocol

This repository follows a **Behavior-First Contract Model** for all UI refactors, especially for:

* Settings
* Onboarding
* Permissions
* Paywalls
* Feature flags
* Access control surfaces

**UI is replaceable. Behavior is not.**

Any agent (human or AI) working in this repo **must follow the phased process below**.

---

## Core Principles (Non-Negotiable)

1. **Settings are APIs**

   * Every toggle, selector, or button is a behavioral contract.
   * Storage keys, side effects, and read locations matter more than layout.

2. **Behavior precedes UI**

   * UI must adapt to behavior, not the other way around.
   * If UI cannot express behavior cleanly, behavior must be stabilized first.

3. **Phases must not be collapsed**

   * Analysis, stabilization, and UI work are separate concerns.
   * Combining them increases regression risk.

4. **Small diffs beat clever refactors**

   * Changes must be reviewable in one sitting.
   * “While we’re here” changes are explicitly forbidden.

---

## Phase A — Discovery (Read-Only Analysis)

**Goal:** Understand reality, not intention.

### Rules

* ❌ Do NOT modify code
* ❌ Do NOT refactor
* ❌ Do NOT redesign UI
* ❌ Do NOT rename variables or storage keys
* ✅ Analysis only

### Required Outputs

For all relevant UI surfaces:

* File inventory (views, state, services)
* Settings contract table:

  * UI label
  * Storage key / variable
  * Default value
  * Write locations
  * Read locations
  * Side effects
  * Downstream dependencies
* Written dependency graph
* Red flags:

  * Orphaned settings
  * Implicit side effects
  * Multi-behavior flags
  * Dev/debug leakage
* Classification:

  * Safe-to-move
  * Not-safe-to-move

### Exit Condition

The agent must explicitly state:

> **“Analysis complete. Safe to proceed to stabilization.”**

If this cannot be stated, the agent must explain why.

---

## Phase B — Stabilization (Small, Surgical)

**Goal:** Prevent future UI work from fossilizing known problems.

### Allowed Changes

* Restore missing core behavior
* Remove or wire orphaned settings
* Make implicit behavior explicit (comments, derived variables)
* Add **contract comments** near state definitions
* Guard dev-only or debug features

### Forbidden Changes

* ❌ UI redesign
* ❌ Cosmetic refactors
* ❌ Storage key renames (unless strictly required)
* ❌ Behavior changes not required by Phase C
* ❌ Broad cleanup

### Constraints

* Diff must be minimal
* Behavior must remain unchanged except for intentional fixes
* All existing flows must remain reachable

### Exit Condition

The agent must explicitly state:

> **“Behavior contract stabilized. Safe for UI replacement.”**

---

## Phase C — UI Replacement (Behavior Locked)

**Goal:** Replace UI without altering behavior.

### Rules

* ❌ No logic changes
* ❌ No state renaming
* ❌ No new side effects
* ✅ UI is a thin adapter over existing contracts

### Requirements

* Fewer sections than before
* Progressive disclosure
* Advanced / dev features gated
* One-to-one mapping:

  * UI control → known contract entry

### Verification Checklist

* Every control maps to an existing contract
* No orphaned UI
* Core product differentiators are visible
* Layout ports cleanly to native frameworks (e.g. SwiftUI Sections)

### Exit Condition

The agent must confirm:

> **“All existing behavior preserved.”**

---

## Contract Comments (Required)

When stabilizing or introducing behavior relied on by UI, add comments like:

```swift
// SETTINGS CONTRACT:
// This flag controls post-verification confirmation behavior.
// Assumed by Settings UI and verification flow.
// Do not change without updating the Settings contract.
```

These comments are mandatory and protect against accidental regressions.

---

## Why This Exists

This protocol exists to:

* Reduce regression risk
* Preserve product behavior
* Enable safe UI evolution
* Make AI agents predictable and auditable
* Prevent “helpful” refactors from breaking core flows

If you are unsure which phase you are in — **stop and ask**.

---

## Summary Rule

> **Behavior first. UI second. Always.**
