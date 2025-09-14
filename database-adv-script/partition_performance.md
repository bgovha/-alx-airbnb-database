# Partitioning Large Tables

## Before Partitioning

``` sql
EXPLAIN ANALYZE
SELECT * FROM Booking
WHERE start_date BETWEEN '2023-01-01' AND '2023-12-31';
```

### EXPLAIN ANALYZE Result (Before Partitioning)

"Seq Scan on booking  (cost=0.00..1.90 rows=19 width=78) (actual time=0.037..0.041 rows=20 loops=1)"
"  Filter: ((start_date >= '2023-01-01'::date) AND (start_date <= '2023-12-31'::date))"
"  Rows Removed by Filter: 40"
"Planning Time: 0.172 ms"
"Execution Time: 0.074 ms"

## After Partitioning

``` sql
EXPLAIN ANALYZE
SELECT * FROM Booking
WHERE start_date BETWEEN '2023-01-01' AND '2023-12-31';
```

### EXPLAIN ANALYZE Result (After Partitioning)

"Seq Scan on booking_2023 booking  (cost=0.00..17.35 rows=2 width=138) (actual time=0.024..0.026 rows=20 loops=1)"
"  Filter: ((start_date >= '2023-01-01'::date) AND (start_date <= '2023-12-31'::date))"
"Planning Time: 3.520 ms"
"Execution Time: 0.042 ms"