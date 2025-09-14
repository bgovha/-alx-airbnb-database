SELECT 
    u.user_id,
    u.name AS user_name,
    u.email,
    COUNT(b.booking_id) AS total_bookings,
    MIN(b.check_in) AS first_booking_date,
    MAX(b.check_in) AS last_booking_date
FROM users u
LEFT JOIN bookings b ON u.user_id = b.user_id
GROUP BY u.user_id, u.name, u.email
ORDER BY total_bookings DESC, u.name;

SELECT 
    p.property_id,
    p.title AS property_title,
    p.price,
    COUNT(b.booking_id) AS total_bookings,
    ROW_NUMBER() OVER (ORDER BY COUNT(b.booking_id) DESC) AS booking_rank,
    ROUND(AVG(r.rating), 2) AS average_rating
FROM properties p
LEFT JOIN bookings b ON p.property_id = b.property_id
LEFT JOIN reviews r ON p.property_id = r.property_id
GROUP BY p.property_id, p.title, p.price
ORDER BY total_bookings DESC;

SELECT 
    p.property_id,
    p.title AS property_title,
    p.price,
    COUNT(b.booking_id) AS total_bookings,
    RANK() OVER (ORDER BY COUNT(b.booking_id) DESC) AS overall_rank,
    RANK() OVER (PARTITION BY p.price_range ORDER BY COUNT(b.booking_id) DESC) AS price_category_rank,
    ROUND(AVG(r.rating), 2) AS average_rating,
    NTILE(4) OVER (ORDER BY COUNT(b.booking_id) DESC) AS popularity_quartile
FROM properties p
LEFT JOIN bookings b ON p.property_id = b.property_id
LEFT JOIN reviews r ON p.property_id = r.property_id
CROSS JOIN (
    SELECT 
        CASE 
            WHEN price < 100 THEN 'Budget'
            WHEN price BETWEEN 100 AND 200 THEN 'Mid-range'
            ELSE 'Luxury'
        END AS price_range
) pr
GROUP BY p.property_id, p.title, p.price, pr.price_range
ORDER BY overall_rank;

SELECT 
    DATE(b.check_in) AS booking_date,
    COUNT(b.booking_id) AS daily_bookings,
    SUM(COUNT(b.booking_id)) OVER (ORDER BY DATE(b.check_in)) AS cumulative_bookings,
    AVG(COUNT(b.booking_id)) OVER (ORDER BY DATE(b.check_in) ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS weekly_moving_avg
FROM bookings b
WHERE b.check_in IS NOT NULL
GROUP BY DATE(b.check_in)
ORDER BY booking_date;

SELECT 
    u.user_id,
    u.name,
    COUNT(b.booking_id) AS total_bookings,
    RANK() OVER (ORDER BY COUNT(b.booking_id) DESC) AS user_rank,
    DATEDIFF(MAX(b.check_in), MIN(b.check_in)) AS booking_time_span,
    AVG(DATEDIFF(b.check_out, b.check_in)) OVER (PARTITION BY u.user_id) AS avg_stay_length
FROM users u
LEFT JOIN bookings b ON u.user_id = b.user_id
GROUP BY u.user_id, u.name
HAVING COUNT(b.booking_id) > 0
ORDER BY user_rank;

