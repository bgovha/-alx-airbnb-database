-- partitioning.sql
-- Table partitioning implementation for bookings table

-- 1. Create the main partitioned table
CREATE TABLE bookings_partitioned (
    booking_id SERIAL,
    user_id INT NOT NULL,
    property_id INT NOT NULL,
    check_in DATE NOT NULL,
    check_out DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    total_amount DECIMAL(10, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (booking_id, check_in)
) PARTITION BY RANGE (check_in);

-- 2. Create partitions for different time periods
-- Historical data (pre-2023)
CREATE TABLE bookings_historical PARTITION OF bookings_partitioned
    FOR VALUES FROM ('2000-01-01') TO ('2023-01-01');

-- 2023 data
CREATE TABLE bookings_2023 PARTITION OF bookings_partitioned
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');

-- 2024 data  
CREATE TABLE bookings_2024 PARTITION OF bookings_partitioned
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

-- 2025 data
CREATE TABLE bookings_2025 PARTITION OF bookings_partitioned
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

-- Future bookings
CREATE TABLE bookings_future PARTITION OF bookings_partitioned
    FOR VALUES FROM ('2026-01-01') TO ('2100-01-01');

-- 3. Create indexes on partitioned tables
CREATE INDEX idx_bookings_partitioned_check_in ON bookings_partitioned(check_in);
CREATE INDEX idx_bookings_partitioned_user_id ON bookings_partitioned(user_id);
CREATE INDEX idx_bookings_partitioned_property_id ON bookings_partitioned(property_id);
CREATE INDEX idx_bookings_partitioned_status ON bookings_partitioned(status);

-- 4. Copy data from original bookings table to partitioned table
INSERT INTO bookings_partitioned 
SELECT * FROM bookings;

-- 5. Optional: Create a view for backward compatibility
CREATE OR REPLACE VIEW bookings AS
SELECT * FROM bookings_partitioned;

-- 6. Create function to automatically create new partitions
CREATE OR REPLACE FUNCTION create_booking_partition_if_not_exists(year INTEGER)
RETURNS void AS $$
DECLARE
    partition_start DATE;
    partition_end DATE;
    partition_name TEXT;
BEGIN
    partition_start := format('%s-01-01', year);
    partition_end := format('%s-01-01', year + 1);
    partition_name := format('bookings_%s', year);
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE tablename = partition_name
    ) THEN
        EXECUTE format(
            'CREATE TABLE %I PARTITION OF bookings_partitioned
            FOR VALUES FROM (%L) TO (%L)',
            partition_name, partition_start, partition_end
        );
        RAISE NOTICE 'Created partition: %', partition_name;
    ELSE
        RAISE NOTICE 'Partition % already exists', partition_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 7. Create trigger function for automatic partition creation
CREATE OR REPLACE FUNCTION bookings_partition_trigger()
RETURNS trigger AS $$
BEGIN
    -- Ensure partition exists for the check_in year
    PERFORM create_booking_partition_if_not_exists(EXTRACT(YEAR FROM NEW.check_in)::INTEGER);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 8. Create trigger to automatically create partitions
CREATE TRIGGER trigger_bookings_partition
    BEFORE INSERT ON bookings_partitioned
    FOR EACH ROW
    EXECUTE FUNCTION bookings_partition_trigger();

  -- partitioning.sql
-- Performance testing queries

-- 1. Test query on non-partitioned table (if still exists)
EXPLAIN ANALYZE
SELECT COUNT(*) 
FROM bookings 
WHERE check_in BETWEEN '2024-01-01' AND '2024-06-30';

-- 2. Test query on partitioned table
EXPLAIN ANALYZE
SELECT COUNT(*) 
FROM bookings_partitioned 
WHERE check_in BETWEEN '2024-01-01' AND '2024-06-30';

-- 3. Complex query with joins on partitioned table
EXPLAIN ANALYZE
SELECT 
    b.booking_id,
    b.check_in,
    b.check_out,
    u.first_name,
    u.last_name,
    p.title as property_title,
    b.total_amount
FROM bookings_partitioned b
JOIN users u ON b.user_id = u.user_id
JOIN properties p ON b.property_id = p.property_id
WHERE b.check_in BETWEEN '2024-03-01' AND '2024-05-31'
AND b.status = 'confirmed'
ORDER BY b.check_in;

-- 4. Test different date ranges
EXPLAIN ANALYZE
SELECT 
    EXTRACT(MONTH FROM check_in) as month,
    COUNT(*) as bookings_count,
    AVG(total_amount) as avg_amount
FROM bookings_partitioned
WHERE check_in BETWEEN '2024-01-01' AND '2024-12-31'
GROUP BY EXTRACT(MONTH FROM check_in)
ORDER BY month;

-- 5. Test cross-partition query
EXPLAIN ANALYZE
SELECT 
    EXTRACT(YEAR FROM check_in) as year,
    COUNT(*) as yearly_bookings
FROM bookings_partitioned
WHERE check_in BETWEEN '2023-01-01' AND '2024-12-31'
GROUP BY EXTRACT(YEAR FROM check_in)
ORDER BY year;


-- partitioning.sql
-- Monitoring and maintenance queries

-- 1. Check partition information
SELECT 
    nmsp_parent.nspname AS parent_schema,
    parent.relname AS parent_table,
    nmsp_child.nspname AS child_schema, 
    child.relname AS child_table,
    pg_get_expr(child.relpartbound, child.oid) AS partition_bound
FROM pg_inherits
JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
JOIN pg_class child ON pg_inherits.inhrelid = child.oid
JOIN pg_namespace nmsp_parent ON nmsp_parent.oid = parent.relnamespace
JOIN pg_namespace nmsp_child ON nmsp_child.oid = child.relnamespace
WHERE parent.relname = 'bookings_partitioned';

-- 2. Check partition sizes
SELECT 
    table_name,
    pg_size_pretty(pg_total_relation_size(table_name)) as size
FROM information_schema.tables 
WHERE table_name LIKE 'bookings_%'
ORDER BY table_name;

-- 3. Analyze partition usage in queries
EXPLAIN (ANALYZE, VERBOSE)
SELECT * FROM bookings_partitioned
WHERE check_in = '2024-05-15';

-- 4. Create maintenance function for old data
CREATE OR REPLACE FUNCTION archive_old_bookings(retention_years INTEGER DEFAULT 2)
RETURNS void AS $$
BEGIN
    -- Create archive table if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'bookings_archive') THEN
        CREATE TABLE bookings_archive AS TABLE bookings_partitioned WITH NO DATA;
    END IF;
    
    -- Move old data to archive
    WITH moved_rows AS (
        DELETE FROM bookings_partitioned
        WHERE check_in < CURRENT_DATE - (retention_years * 365)
        RETURNING *
    )
    INSERT INTO bookings_archive SELECT * FROM moved_rows;
    
    RAISE NOTICE 'Archived bookings older than % years', retention_years;
END;
$$ LANGUAGE plpgsql;

-- 5. Schedule regular maintenance
-- (This would typically be set up as a cron job or using pg_cron)

