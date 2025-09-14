-- performance.sql
-- Performance comparison

-- Time the original query
\timing on

-- Original query execution time
EXPLAIN ANALYZE
SELECT ... -- original complex query

-- Optimized query execution time  
EXPLAIN ANALYZE
WITH property_ratings AS (...)
SELECT ... -- optimized query

\timing off

-- Check index usage
SELECT 
    relname,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch
FROM pg_stat_user_tables
WHERE relname IN ('bookings', 'users', 'properties', 'payments', 'reviews');