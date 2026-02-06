# /cp_drawer_repair

Diagnose and repair stuck drawer sessions.

## Symptoms
- "Processing complete. 1 transaction(s) had errors and were not processed"
- Drawer sessions stuck on reconcile
- "tickets with errors moved to new drawer session" message

## Root Causes
1. Orphan SY_EVENT records referencing empty drawer sessions
2. Orphan PS_TKT_PST_LIN_WRK records from failed post attempts
3. PS_DOC_HDR.ERR_REF populated preventing re-post

## Repair Order
1. Backup database
2. Run diagnostics (Section 1)
3. Clear work table orphans (Section 2)
4. Clear orphan events (Section 3)
5. Verify and post

## Script Location
prompts/snippets/drawer-session-stuck-repair.sql
