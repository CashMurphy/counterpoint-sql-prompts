# 🧰 CounterPoint SQL 8.6.1.1 — Incident Runbook

Prime directives:
- Never write to SQL unless authorized
- Never touch encrypted or tokenized payment data
- Never recommend blind rebuilds
- Observation → Explanation → Action

## First Response
- Is POS live?
- What is expected vs observed?
- POS, Back Office, report, or SQL truth?
- Capture date range, docs, stations, cashiers

Create a case folder under evidence/cases/.

## Common Incidents

### POS totals ≠ reports
Stored rollups and inclusion rules differ.

### Tender totals off
Pay-ins, payouts, rounding, split tenders.

### Missing transaction
Voided, reversed, or posted under a different key.

### Inventory incorrect
Movement posted, valuation misunderstood.

### Margin wrong
Valuation method mismatch or returns behavior.

### Gift card / store credit
Multi-table liability flow.

### Sales tax
Rounding or rule changes mid-period.

## Closure
Summarize root cause, evidence, NCR-supported path, and verification.
