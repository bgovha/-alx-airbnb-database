SELECT 
    b.booking_id,
    b.check_in,
    b.check_out,
    u.user_id,
    u.name AS user_name,
    u.email
FROM bookings b
INNER JOIN users u ON b.user_id = u.user_id
ORDER BY b.booking_id;

SELECT 
    p.property_id,
    p.title AS property_title,
    p.description,
    r.review_id,
    r.rating,
    r.comment,
    r.created_at AS review_date
FROM properties p
LEFT JOIN reviews r ON p.property_id = (
    SELECT pr.property_id 
    FROM bookings b 
    JOIN properties pr ON b.property_id = pr.property_id 
    WHERE b.booking_id = r.booking_id
)
ORDER BY p.property_id, r.rating DESC;

SELECT 
    COALESCE(u.user_id, b.user_id) AS user_identifier,
    u.name AS user_name,
    u.email,
    b.booking_id,
    b.property_id,
    b.check_in,
    b.check_out,
    CASE 
        WHEN u.user_id IS NULL THEN 'Orphaned booking'
        WHEN b.booking_id IS NULL THEN 'User with no bookings'
        ELSE 'Valid booking'
    END AS status
FROM users u
FULL OUTER JOIN bookings b ON u.user_id = b.user_id
ORDER BY 
    CASE 
        WHEN u.user_id IS NULL THEN 1
        WHEN b.booking_id IS NULL THEN 2
        ELSE 3
    END,
    u.user_id,
    b.booking_id;