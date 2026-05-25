-- Initial exploration: viewing trip requests alongside their status
-- to understand the data structure before analysis
SELECT requested_at, status
FROM trips;

-- Data is in day time but only interested in the hour
-- Status of the trips completed, in_progress and cancelled
-- Order the total trips in descending order
WITH hourly_stats AS (
    SELECT 
        EXTRACT(HOUR FROM requested_at) AS trip_hour,
        COUNT(CASE WHEN status = 'completed' THEN 1 END) AS total_completed,
        COUNT(CASE WHEN status = 'in_progress' THEN 1 END) AS total_ip,
        COUNT(CASE WHEN status = 'cancelled' THEN 1 END) AS total_cancelled
    FROM trips
    GROUP BY 1
)
(SELECT 'Completed' AS status_type, 
        trip_hour, 
        total_completed AS trip_count 
FROM hourly_stats 
ORDER BY total_completed DESC 
LIMIT 5)
UNION ALL
(SELECT 'In Progress' AS status_type, 
        trip_hour, 
        total_ip AS trip_count 
FROM hourly_stats 
ORDER BY total_ip DESC 
LIMIT 5)
UNION ALL
(SELECT 'Cancelled' AS status_type, 
        trip_hour, 
        total_cancelled AS trip_count 
FROM hourly_stats 
ORDER BY total_cancelled DESC 
LIMIT 5);

-- Average total trips and std dev to determine above-average hours, average and below-average hours
WITH hourly_stats AS (
    SELECT
    EXTRACT(HOUR FROM requested_at) AS trip_hour,
    COUNT(*) AS total_trips
FROM trips
WHERE status = 'completed'
GROUP BY 1
)
SELECT ROUND(AVG(total_trips), 2) AS avg_total_trips,
        ROUND(STDDEV_SAMP(total_trips), 2) AS std_dev_trips
FROM hourly_stats;

-- Average being 701.13, std dev being 26.95
-- Finding out peak hours of performance for the entire dataset with the status of the trip solely completed
WITH hourly_stats AS (
    SELECT
    EXTRACT(HOUR FROM requested_at) AS trip_hour,
    COUNT(*) AS total_trips
FROM trips
WHERE status ='completed'
GROUP BY 1
),
metrics AS (
    SELECT ROUND(AVG(total_trips), 2) AS t_avg,
    ROUND(STDDEV_SAMP(total_trips), 2) AS t_dev
FROM hourly_stats
)
SELECT h.trip_hour, h.total_trips,
    CASE
    WHEN h.total_trips > (m.t_avg + m.t_dev) THEN 'Above Average Peak'
    WHEN h.total_trips < (m.t_avg - m.t_dev) THEN 'Below Average Low'
    ELSE 'Normal Average'
    END AS operation_metrics
FROM hourly_stats h
CROSS JOIN metrics m
ORDER BY h.total_trips DESC;

-- Discovering the locations where these hours were met
-- And since we are working only with the output provided below. We create a view to make it easier to work with
CREATE VIEW zones AS (
    SELECT l.city, l.zone_type, t.requested_at, t.pickup_location_id
FROM locations l
JOIN trips t ON t.pickup_location_id = l.location_id
WHERE t.status = 'completed'
)

-- Shifting from the macro perspective to the micro perspective
-- Creating a condition where we have the above average peak hours by each city
WITH hourly_zone_stats AS (
    SELECT
        EXTRACT(HOUR FROM requested_at) AS trip_hour,
        city,
        zone_type,
        COUNT(*) AS total_trips
    FROM zones
    GROUP BY 1, 2, 3
),
metrics_by_city AS (
    SELECT *,
        -- Calculates metrics dynamically per city across all its hours/zones
        ROUND(AVG(total_trips) OVER(PARTITION BY city), 2) AS city_avg,
        ROUND(STDDEV_SAMP(total_trips) OVER(PARTITION BY city), 2) AS city_dev
    FROM hourly_zone_stats
)
SELECT 
    city, 
    zone_type, 
    total_trips,
    CASE 
        WHEN total_trips > (city_avg + city_dev) THEN 'Above Average Peak'
        WHEN total_trips < (city_avg - city_dev) THEN 'Below Average Low'
        ELSE 'Normal Average'
    END AS operation_metrics, 
    trip_hour
FROM metrics_by_city
ORDER BY city ASC, total_trips DESC;



