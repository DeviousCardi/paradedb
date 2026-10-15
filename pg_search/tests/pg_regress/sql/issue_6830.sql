\i common/common_setup.sql

-- Window functions over a GROUP BY must see every group, even when the query
-- has a LIMIT (issue #6830). The LIMIT applies after the WindowAgg, so the
-- Aggregate Scan must not fold it into the terms aggregation bucket size.
SET paradedb.enable_aggregate_custom_scan TO on;

DROP TABLE IF EXISTS issue_6830 CASCADE;
CREATE TABLE issue_6830 (id SERIAL PRIMARY KEY, n INT);
INSERT INTO issue_6830 (n) VALUES (1), (2), (3);
CREATE INDEX issue_6830_idx ON issue_6830 USING paradedb (id, n);

-- Test 1: the issue's repro (no ORDER BY). Expected: total = 6, num_groups = 3.
EXPLAIN (COSTS OFF, TIMING OFF, VERBOSE)
SELECT SUM(n) OVER () AS total, COUNT(*) OVER () AS num_groups
FROM issue_6830
WHERE id @@@ pdb.all()
GROUP BY n
LIMIT 1;

SELECT SUM(n) OVER () AS total, COUNT(*) OVER () AS num_groups
FROM issue_6830
WHERE id @@@ pdb.all()
GROUP BY n
LIMIT 1;

-- Test 2: LIMIT + OFFSET. Expected: total = 6, num_groups = 3.
EXPLAIN (COSTS OFF, TIMING OFF, VERBOSE)
SELECT SUM(n) OVER () AS total, COUNT(*) OVER () AS num_groups
FROM issue_6830
WHERE id @@@ pdb.all()
GROUP BY n
LIMIT 1 OFFSET 1;

SELECT SUM(n) OVER () AS total, COUNT(*) OVER () AS num_groups
FROM issue_6830
WHERE id @@@ pdb.all()
GROUP BY n
LIMIT 1 OFFSET 1;

-- Test 3: ORDER BY an aggregate that TopK accepts. Expected: total = 6, num_groups = 3.
EXPLAIN (COSTS OFF, TIMING OFF, VERBOSE)
SELECT SUM(n) OVER () AS total, COUNT(*) OVER () AS num_groups
FROM issue_6830
WHERE id @@@ pdb.all()
GROUP BY n
ORDER BY COUNT(*) DESC
LIMIT 1;

SELECT SUM(n) OVER () AS total, COUNT(*) OVER () AS num_groups
FROM issue_6830
WHERE id @@@ pdb.all()
GROUP BY n
ORDER BY COUNT(*) DESC
LIMIT 1;

-- Test 4: without a window function the LIMIT is still pushed into the bucket size.
EXPLAIN (COSTS OFF, TIMING OFF, VERBOSE)
SELECT n, COUNT(*)
FROM issue_6830
WHERE id @@@ pdb.all()
GROUP BY n
LIMIT 1;

-- Test 5: same results as with the Aggregate Scan disabled.
SET paradedb.enable_aggregate_custom_scan TO off;

SELECT SUM(n) OVER () AS total, COUNT(*) OVER () AS num_groups
FROM issue_6830
WHERE id @@@ pdb.all()
GROUP BY n
LIMIT 1;

RESET paradedb.enable_aggregate_custom_scan;

DROP TABLE issue_6830;

\i common/common_cleanup.sql
