-- performance.sql
-- Initial complex query (before optimization)
SELECT 
    b.booking_id,
    b.check_in,
    b.check_out,
    b.status as booking_status,
    b.total_amount,
    
    u.user_id,
    u.first_name,
    u.last_name,
    u.email,
    u.phone,
    
    p.property_id,
    p.title as property_title,
    p.description,
    p.price_per_night,
    p.location,
    
    pd.bedrooms,
    pd.bathrooms,
    pd.amenities,
    
    pay.payment_id,
    pay.amount as payment_amount,
    pay.status as payment_status,
    pay.payment_date,
    pay.payment_method,
    
    (SELECT COUNT(*) FROM reviews r WHERE r.booking_id = b.booking_id) as review_count,
    (SELECT AVG(rating) FROM reviews r WHERE r.property_id = p.property_id) as avg_property_rating
    
FROM bookings b
LEFT JOIN users u ON b.user_id = u.user_id
LEFT JOIN properties p ON b.property_id = p.property_id
LEFT JOIN property_details pd ON p.property_id = pd.property_id
LEFT JOIN payments pay ON b.booking_id = pay.booking_id
LEFT JOIN reviews rev ON b.booking_id = rev.booking_id
WHERE b.check_in BETWEEN '2024-01-01' AND '2024-12-31'
ORDER BY b.check_in DESC, u.last_name, u.first_name;

-- Analyze the query performance
EXPLAIN ANALYZE
SELECT 
    b.booking_id,
    b.check_in,
    b.check_out,
    -- ... (same as above)

    -- performance.sql
-- Optimized query (after refactoring)

-- Step 1: Create necessary indexes
CREATE INDEX IF NOT EXISTS idx_bookings_check_in ON bookings(check_in);
CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_property_id ON bookings(property_id);
CREATE INDEX IF NOT EXISTS idx_payments_booking_id ON payments(booking_id);
CREATE INDEX IF NOT EXISTS idx_reviews_property_id ON reviews(property_id);
CREATE INDEX IF NOT EXISTS idx_reviews_booking_id ON reviews(booking_id);

-- Step 2: Use CTEs for pre-aggregation
WITH property_ratings AS (
    SELECT 
        property_id,
        AVG(rating) as avg_rating,
        COUNT(*) as total_reviews
    FROM reviews
    GROUP BY property_id
),
booking_reviews AS (
    SELECT 
        booking_id,
        COUNT(*) as review_count
    FROM reviews
    GROUP BY booking_id
)

-- Step 3: Optimized main query
SELECT 
    b.booking_id,
    b.check_in,
    b.check_out,
    b.status as booking_status,
    b.total_amount,
    
    u.user_id,
    u.first_name,
    u.last_name,
    u.email,
    u.phone,
    
    p.property_id,
    p.title as property_title,
    p.description,
    p.price_per_night,
    p.location,
    
    pd.bedrooms,
    pd.bathrooms,
    pd.amenities,
    
    pay.payment_id,
    pay.amount as payment_amount,
    pay.status as payment_status,
    pay.payment_date,
    pay.payment_method,
    
    COALESCE(br.review_count, 0) as review_count,
    COALESCE(pr.avg_rating, 0) as avg_property_rating,
    pr.total_reviews as property_total_reviews
    
FROM bookings b
INNER JOIN users u ON b.user_id = u.user_id
INNER JOIN properties p ON b.property_id = p.property_id
LEFT JOIN property_details pd ON p.property_id = pd.property_id
LEFT JOIN payments pay ON b.booking_id = pay.booking_id
LEFT JOIN booking_reviews br ON b.booking_id = br.booking_id
LEFT JOIN property_ratings pr ON p.property_id = pr.property_id
WHERE b.check_in BETWEEN '2024-01-01' AND '2024-12-31'
ORDER BY b.check_in DESC;

-- Alternative: Pagination for large result sets
SELECT * FROM (
    SELECT 
        b.booking_id,
        b.check_in,
        b.check_out,
        b.status as booking_status,
        u.first_name,
        u.last_name,
        p.title as property_title,
        pay.status as payment_status,
        ROW_NUMBER() OVER (ORDER BY b.check_in DESC) as row_num
    FROM bookings b
    INNER JOIN users u ON b.user_id = u.user_id
    INNER JOIN properties p ON b.property_id = p.property_id
    LEFT JOIN payments pay ON b.booking_id = pay.booking_id
    WHERE b.check_in BETWEEN '2024-01-01' AND '2024-12-31'
) AS paginated
WHERE row_num BETWEEN 1 AND 50
ORDER BY check_in DESC;

-- performance.sql
-- Materialized View for frequently accessed aggregated data
CREATE MATERIALIZED VIEW IF NOT EXISTS property_performance AS
SELECT 
    p.property_id,
    p.title,
    p.location,
    COUNT(b.booking_id) as total_bookings,
    AVG(b.total_amount) as avg_booking_value,
    AVG(r.rating) as avg_rating,
    COUNT(r.review_id) as total_reviews
FROM properties p
LEFT JOIN bookings b ON p.property_id = b.property_id
LEFT JOIN reviews r ON p.property_id = r.property_id
GROUP BY p.property_id, p.title, p.location;

-- Refresh the materialized view periodically
REFRESH MATERIALIZED VIEW property_performance;

-- Function for specific date range queries
CREATE OR REPLACE FUNCTION get_bookings_with_details(
    start_date DATE, 
    end_date DATE,
    limit_count INT DEFAULT 100
)
RETURNS TABLE (
    booking_id INT,
    check_in DATE,
    check_out DATE,
    user_name TEXT,
    property_title TEXT,
    payment_status TEXT,
    total_amount DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.booking_id,
        b.check_in,
        b.check_out,
        CONCAT(u.first_name, ' ', u.last_name) as user_name,
        p.title as property_title,
        pay.status as payment_status,
        b.total_amount
    FROM bookings b
    INNER JOIN users u ON b.user_id = u.user_id
    INNER JOIN properties p ON b.property_id = p.property_id
    LEFT JOIN payments pay ON b.booking_id = pay.booking_id
    WHERE b.check_in BETWEEN start_date AND end_date
    ORDER BY b.check_in DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Usage
SELECT * FROM get_bookings_with_details('2024-01-01', '2024-12-31', 50);

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

