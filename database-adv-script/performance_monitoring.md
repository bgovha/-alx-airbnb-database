-- Enable performance monitoring features
SET profiling = 1;
SET max_execution_time = 30000;

-- Create a helper function to generate test data
CREATE OR REPLACE FUNCTION generate_test_bookings(num_records INT)
RETURNS void AS $$
DECLARE
    i INT;
BEGIN
    FOR i IN 1..num_records LOOP
        INSERT INTO bookings_partitioned (
            user_id, property_id, check_in, check_out, status, total_amount
        ) VALUES (
            (random() * 1000)::INT + 1,
            (random() * 500)::INT + 1,
            CURRENT_DATE - (random() * 3650)::INT,
            CURRENT_DATE - (random() * 3640)::INT,
            CASE (random() * 3)::INT
                WHEN 0 THEN 'pending'
                WHEN 1 THEN 'confirmed'
                ELSE 'completed'
            END,
            (random() * 1000)::DECIMAL(10, 2) + 50
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Generate test data (1M records)
SELECT generate_test_bookings(1000000);

-- performance_monitoring.sql
-- 1. Frequently used query: User booking history
EXPLAIN ANALYZE
SELECT 
    u.user_id,
    u.first_name,
    u.last_name,
    b.booking_id,
    b.check_in,
    b.check_out,
    b.total_amount,
    p.title as property_title,
    pay.status as payment_status
FROM users u
JOIN bookings_partitioned b ON u.user_id = b.user_id
JOIN properties p ON b.property_id = p.property_id
LEFT JOIN payments pay ON b.booking_id = pay.booking_id
WHERE u.user_id = 123
ORDER BY b.check_in DESC
LIMIT 20;

-- 2. Frequently used query: Property availability search
EXPLAIN ANALYZE
SELECT 
    p.property_id,
    p.title,
    p.location,
    p.price_per_night,
    AVG(r.rating) as avg_rating,
    COUNT(r.review_id) as review_count,
    COUNT(b.booking_id) as total_bookings
FROM properties p
LEFT JOIN reviews r ON p.property_id = r.property_id
LEFT JOIN bookings_partitioned b ON p.property_id = b.property_id
WHERE p.location LIKE '%Paris%'
AND p.price_per_night BETWEEN 50 AND 200
AND p.is_active = true
GROUP BY p.property_id, p.title, p.location, p.price_per_night
HAVING AVG(r.rating) >= 4.0
ORDER BY avg_rating DESC
LIMIT 10;

-- 3. Frequently used query: Revenue reporting by month
EXPLAIN ANALYZE
SELECT 
    EXTRACT(YEAR FROM b.check_in) as year,
    EXTRACT(MONTH FROM b.check_in) as month,
    COUNT(b.booking_id) as booking_count,
    SUM(b.total_amount) as total_revenue,
    AVG(b.total_amount) as avg_booking_value
FROM bookings_partitioned b
WHERE b.check_in BETWEEN '2023-01-01' AND '2024-12-31'
AND b.status = 'completed'
GROUP BY EXTRACT(YEAR FROM b.check_in), EXTRACT(MONTH FROM b.check_in)
ORDER BY year DESC, month DESC;

-- 4. Check current performance metrics
SHOW PROFILES;
SELECT * FROM information_schema.profiling;

-- bottleneck_analysis.sql
-- Common issues identified:
-- 1. Sequential scans on large tables
-- 2. Expensive sort operations
-- 3. Nested loops with large datasets
-- 4. Missing composite indexes

-- Recommended indexes based on query patterns:
CREATE INDEX IF NOT EXISTS idx_users_composite ON users(user_id, first_name, last_name);
CREATE INDEX IF NOT EXISTS idx_properties_search ON properties(location, price_per_night, is_active);
CREATE INDEX IF NOT EXISTS idx_bookings_status_date ON bookings_partitioned(status, check_in);
CREATE INDEX IF NOT EXISTS idx_reviews_property_rating ON reviews(property_id, rating);
CREATE INDEX IF NOT EXISTS idx_payments_booking_status ON payments(booking_id, status);

-- Composite index for revenue reporting
CREATE INDEX IF NOT EXISTS idx_bookings_revenue_report ON bookings_partitioned(
    status, check_in, total_amount
);

-- Covering index for user booking history
CREATE INDEX IF NOT EXISTS idx_bookings_user_cover ON bookings_partitioned(
    user_id, check_in, property_id, total_amount
) INCLUDE (status, check_out);