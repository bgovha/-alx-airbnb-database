SELECT 
    p.property_id,
    p.title,
    p.description,
    avg_rating.average_rating
FROM properties p
INNER JOIN (
    SELECT 
        property_id,
        AVG(rating) as average_rating
    FROM reviews
    GROUP BY property_id
    HAVING AVG(rating) > 4.0
) avg_rating ON p.property_id = avg_rating.property_id
ORDER BY avg_rating.average_rating DESC;

SELECT 
    u.user_id,
    u.name,
    u.email,
    (SELECT COUNT(*) FROM bookings b WHERE b.user_id = u.user_id) as total_bookings
FROM users u
WHERE (SELECT COUNT(*) FROM bookings b WHERE b.user_id = u.user_id) > 3
ORDER BY total_bookings DESC;

SELECT 
    p.property_id,
    p.title
FROM properties p
WHERE NOT EXISTS (
    SELECT 1 
    FROM reviews r 
    WHERE r.property_id = p.property_id
)
ORDER BY p.title;

SELECT 
    u.user_id,
    u.name,
    u.email
FROM users u
WHERE u.user_id IN (
    SELECT DISTINCT b.user_id
    FROM bookings b
    INNER JOIN properties p ON b.property_id = p.property_id
    WHERE p.price BETWEEN 100 AND 300
)
ORDER BY u.name;