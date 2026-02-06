/*
================================================================================
CounterPoint SQL 8.6.1.1 - Stuck Drawer Session Repair Script
================================================================================
Purpose: Diagnose and repair drawer sessions stuck on reconcile with
         "tickets with errors moved to new drawer session" errors

Root Causes:
  1. Orphan SY_EVENT records referencing empty drawer sessions
  2. Orphan PS_TKT_PST_LIN_WRK records from failed post attempts
  3. PS_DOC_HDR.ERR_REF populated preventing re-post

IMPORTANT:
  - BACKUP DATABASE BEFORE RUNNING ANY DELETE/UPDATE STATEMENTS
  - Run diagnostics first (Section 1) before any repairs
  - POS should be inactive or low-activity during repairs

================================================================================
*/

-- ============================================================================
-- SECTION 1: DIAGNOSTICS (Read-Only)
-- ============================================================================

-- 1A. Find orphan SY_EVENT records (empty sessions with errors)
PRINT '=== 1A. Orphan SY_EVENT Records ===';
SELECT
    e.EVENT_NO,
    e.EVENT_TYP,
    e.EVENT_DT,
    e.DRW_SESSION_ID,
    e.TRX_CNT,
    e.POST_CNT,
    e.DB_ERR_CNT,
    CAST(e.SYS_ERR_REF AS varchar(500)) AS SYS_ERR_REF
FROM SY_EVENT e
WHERE e.EVENT_TYP = 'PSP'
  AND e.DB_ERR_CNT = 1
  AND e.DRW_SESSION_ID IS NOT NULL
  AND CAST(e.SYS_ERR_REF AS varchar(max)) LIKE '%moved to a new drawer session%'
ORDER BY e.EVENT_DT DESC;

-- 1B. Count orphan events (sessions with no tickets)
PRINT '=== 1B. Orphan Event Count ===';
SELECT COUNT(*) AS orphan_event_count
FROM SY_EVENT e
WHERE e.EVENT_TYP = 'PSP'
  AND e.DB_ERR_CNT = 1
  AND e.DRW_SESSION_ID IS NOT NULL
  AND CAST(e.SYS_ERR_REF AS varchar(max)) LIKE '%moved to a new drawer session%'
  AND e.DRW_SESSION_ID NOT IN (
      SELECT DISTINCT DRW_SESSION_ID
      FROM PS_DOC_HDR
      WHERE DRW_SESSION_ID IS NOT NULL
  );

-- 1C. Find tickets with posting errors (ERR_REF populated)
PRINT '=== 1C. Tickets with Posting Errors ===';
SELECT
    DOC_ID,
    TKT_NO,
    DOC_TYP,
    TKT_DT,
    DRW_SESSION_ID,
    USR_ID,
    SAL_LIN_TOT,
    ERR_REF
FROM PS_DOC_HDR
WHERE ERR_REF IS NOT NULL
  AND ERR_REF <> ''
ORDER BY TKT_DT DESC;

-- 1D. Find orphan work table records
PRINT '=== 1D. Orphan Work Table Records ===';
SELECT
    w.DOC_ID,
    d.TKT_NO,
    d.TKT_DT,
    d.ERR_REF,
    COUNT(*) AS work_record_count
FROM PS_TKT_PST_LIN_WRK w
LEFT JOIN PS_DOC_HDR d ON w.DOC_ID = d.DOC_ID
GROUP BY w.DOC_ID, d.TKT_NO, d.TKT_DT, d.ERR_REF
ORDER BY d.TKT_DT DESC;

-- 1E. Find unposted drawer sessions
PRINT '=== 1E. Unposted Drawer Sessions ===';
SELECT
    STR_ID, DRW_ID, DRW_SESSION_ID, EVENT_ID,
    EVENT_DT, EVENT_TYP, EVENT_STAT, USR_ID, AMT
FROM PS_DRW_SESSION_EVENT
WHERE EVENT_STAT NOT IN ('P', 'X')
ORDER BY EVENT_DT DESC;


-- ============================================================================
-- SECTION 2: REPAIR - ORPHAN WORK TABLE RECORDS
-- Run this FIRST if Section 1D returned results
-- ============================================================================

/*
-- 2A. Delete orphan work table records for tickets with errors
-- Uncomment and run after identifying DOC_IDs from Section 1D

DECLARE @ErrorDocIds TABLE (DOC_ID bigint);

INSERT INTO @ErrorDocIds (DOC_ID)
SELECT DISTINCT DOC_ID
FROM PS_DOC_HDR
WHERE ERR_REF IS NOT NULL
  AND ERR_REF <> ''
  AND ERR_REF LIKE '%PS_TKT_PST_LIN_WRK%';

-- Delete work table records
DELETE FROM PS_TKT_PST_LIN_WRK
WHERE DOC_ID IN (SELECT DOC_ID FROM @ErrorDocIds);

PRINT 'Deleted work table records: ' + CAST(@@ROWCOUNT AS varchar(10));

-- Clear ERR_REF on affected tickets
UPDATE PS_DOC_HDR
SET ERR_REF = NULL
WHERE DOC_ID IN (SELECT DOC_ID FROM @ErrorDocIds);

PRINT 'Cleared ERR_REF on tickets: ' + CAST(@@ROWCOUNT AS varchar(10));
*/


-- ============================================================================
-- SECTION 3: REPAIR - ORPHAN SY_EVENT RECORDS
-- Run this AFTER Section 2 if Section 1B returned count > 0
-- ============================================================================

/*
-- 3A. First verify all orphan sessions are truly empty
SELECT e.EVENT_NO, e.DRW_SESSION_ID, e.EVENT_DT,
       COUNT(d.DOC_ID) AS ticket_count
FROM SY_EVENT e
LEFT JOIN PS_DOC_HDR d ON e.DRW_SESSION_ID = d.DRW_SESSION_ID
WHERE e.EVENT_TYP = 'PSP'
  AND e.DB_ERR_CNT = 1
  AND e.DRW_SESSION_ID IS NOT NULL
  AND CAST(e.SYS_ERR_REF AS varchar(max)) LIKE '%moved to a new drawer session%'
GROUP BY e.EVENT_NO, e.DRW_SESSION_ID, e.EVENT_DT
HAVING COUNT(d.DOC_ID) > 0
ORDER BY e.EVENT_DT DESC;

-- If above returns 0 rows, safe to proceed with cleanup

-- 3B. Delete from SY_DIST first (child table)
DELETE FROM SY_DIST
WHERE EVENT_NO IN (
    SELECT EVENT_NO
    FROM SY_EVENT
    WHERE EVENT_TYP = 'PSP'
      AND DB_ERR_CNT = 1
      AND DRW_SESSION_ID IS NOT NULL
      AND CAST(SYS_ERR_REF AS varchar(max)) LIKE '%moved to a new drawer session%'
      AND DRW_SESSION_ID NOT IN (
          SELECT DISTINCT DRW_SESSION_ID
          FROM PS_DOC_HDR
          WHERE DRW_SESSION_ID IS NOT NULL
      )
);

PRINT 'Deleted SY_DIST records: ' + CAST(@@ROWCOUNT AS varchar(10));

-- 3C. Delete orphan SY_EVENT records
DELETE FROM SY_EVENT
WHERE EVENT_TYP = 'PSP'
  AND DB_ERR_CNT = 1
  AND DRW_SESSION_ID IS NOT NULL
  AND CAST(SYS_ERR_REF AS varchar(max)) LIKE '%moved to a new drawer session%'
  AND DRW_SESSION_ID NOT IN (
      SELECT DISTINCT DRW_SESSION_ID
      FROM PS_DOC_HDR
      WHERE DRW_SESSION_ID IS NOT NULL
  );

PRINT 'Deleted orphan SY_EVENT records: ' + CAST(@@ROWCOUNT AS varchar(10));
*/


-- ============================================================================
-- SECTION 4: POST-REPAIR VERIFICATION
-- ============================================================================

/*
-- 4A. Verify no orphan events remain
SELECT COUNT(*) AS remaining_orphans
FROM SY_EVENT
WHERE EVENT_TYP = 'PSP'
  AND DB_ERR_CNT = 1
  AND DRW_SESSION_ID IS NOT NULL
  AND CAST(SYS_ERR_REF AS varchar(max)) LIKE '%moved to a new drawer session%'
  AND DRW_SESSION_ID NOT IN (
      SELECT DISTINCT DRW_SESSION_ID
      FROM PS_DOC_HDR
      WHERE DRW_SESSION_ID IS NOT NULL
  );

-- 4B. Verify no tickets with ERR_REF remain
SELECT COUNT(*) AS tickets_with_errors
FROM PS_DOC_HDR
WHERE ERR_REF IS NOT NULL AND ERR_REF <> '';

-- 4C. Verify work table is clean for error tickets
SELECT COUNT(*) AS orphan_work_records
FROM PS_TKT_PST_LIN_WRK w
WHERE w.DOC_ID IN (
    SELECT DOC_ID FROM PS_DOC_HDR
    WHERE ERR_REF IS NOT NULL AND ERR_REF <> ''
);
*/


-- ============================================================================
-- SECTION 5: BACKUP COMMAND (SQL Server Express Compatible)
-- ============================================================================

/*
-- Run before any repairs:
BACKUP DATABASE [GRAPEVINE]
TO DISK = 'C:\RCS\SQL_Backup\Grapevine_PreRepair.bak'
WITH FORMAT, INIT, NAME = 'Pre-Repair Backup';
*/


-- ============================================================================
-- QUICK REFERENCE: Repair Order
-- ============================================================================
/*
1. BACKUP DATABASE
2. Run Section 1 (Diagnostics) - identify issues
3. Run Section 2 (Work Table Cleanup) - if 1D found records
4. Run Section 3 (Orphan Event Cleanup) - if 1B count > 0
5. Run Section 4 (Verification)
6. Post drawer sessions via Back Office
*/
