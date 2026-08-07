SELECT
    apc."Season Year",
    apc."Season Number",
    apc."Season",
    apc."Service Day Category",
    apc."Route Short Name",
    apc."Route Name",
    apc."Direction",
    apc."Trip",

ISNULL(
    fare."Average Daily Boardings",
    0
) AS "Average Daily Boardings",

ISNULL(
    fare."Total Fare Counts",
    0
) AS "Total Fare Counts",

ISNULL(
    fare."Fare Service Days",
    0
) AS "Fare Service Days",

apc."Median Passenger Load",

------------------------------------------------------------
-- ARRIVAL ON-TIME PERFORMANCE
------------------------------------------------------------

apc."On Time Arrivals",

ROUND(
    100.0 * apc."On Time Arrivals"
    / NULLIF(apc."Total Arrival Events", 0),
    1
) AS "% Arrival On Time",

apc."Early Arrivals",

ROUND(
    100.0 * apc."Early Arrivals"
    / NULLIF(apc."Total Arrival Events", 0),
    1
) AS "% Arrival Early",

apc."Late Arrivals",

ROUND(
    100.0 * apc."Late Arrivals"
    / NULLIF(apc."Total Arrival Events", 0),
    1
) AS "% Arrival Late",

apc."Total Arrival Events",

------------------------------------------------------------
-- DEPARTURE ON-TIME PERFORMANCE
------------------------------------------------------------

apc."On Time Departures",

ROUND(
    100.0 * apc."On Time Departures"
    / NULLIF(apc."Total Departure Events", 0),
    1
) AS "% Departure On Time",

apc."Early Departures",

ROUND(
    100.0 * apc."Early Departures"
    / NULLIF(apc."Total Departure Events", 0),
    1
) AS "% Departure Early",

apc."Late Departures",

ROUND(
    100.0 * apc."Late Departures"
    / NULLIF(apc."Total Departure Events", 0),
    1
) AS "% Departure Late",

apc."Total Departure Events"

FROM (

------------------------------------------------------------
-- APC DATA
-- Used for median passenger load and on-time performance
------------------------------------------------------------

SELECT
    y."Season Year",
    y."Season Number",
    y."Season",
    y."Service Day Category",
    y."Route Short Name",
    y."Route Name",
    y."Direction",
    y."Trip",

    MAX(
        y."Median Passenger Load"
    ) AS "Median Passenger Load",

    SUM(
        CASE
            WHEN y."Arrive Delta Seconds"
                 BETWEEN -60 AND 300
            THEN 1
            ELSE 0
        END
    ) AS "On Time Arrivals",

    SUM(
        CASE
            WHEN y."Arrive Delta Seconds" < -60
            THEN 1
            ELSE 0
        END
    ) AS "Early Arrivals",

    SUM(
        CASE
            WHEN y."Arrive Delta Seconds" > 300
            THEN 1
            ELSE 0
        END
    ) AS "Late Arrivals",

    COUNT(y."Arrive Delta Seconds") AS "Total Arrival Events",

    SUM(
        CASE
            WHEN y."Depart Delta Seconds"
                 BETWEEN -60 AND 300
            THEN 1
            ELSE 0
        END
    ) AS "On Time Departures",

    SUM(
        CASE
            WHEN y."Depart Delta Seconds" < -60
            THEN 1
            ELSE 0
        END
    ) AS "Early Departures",

    SUM(
        CASE
            WHEN y."Depart Delta Seconds" > 300
            THEN 1
            ELSE 0
        END
    ) AS "Late Departures",

    COUNT(y."Depart Delta Seconds") AS "Total Departure Events"

FROM (
    SELECT
        x.*,

        PERCENTILE_CONT(0.5)
        WITHIN GROUP (
            ORDER BY x."Passenger Load"
        )
        OVER (
            PARTITION BY
                x."Season Year",
                x."Season Number",
                x."Season",
                x."Service Day Category",
                x."Route Short Name",
                x."Route Name",
                x."Direction",
                x."Trip"
        ) AS "Median Passenger Load"

    FROM (
        SELECT

            ------------------------------------------------
            -- Season year
            -- December belongs to the following year
            ------------------------------------------------

            CASE
                WHEN dd.Month = 12
                THEN dd.Year + 1
                ELSE dd.Year
            END AS "Season Year",

            ------------------------------------------------
            -- Season sorting number
            ------------------------------------------------

            CASE
                WHEN dd.Month IN (12,1,2)
                THEN 1

                WHEN dd.Month IN (3,4,5)
                THEN 2

                WHEN dd.Month IN (6,7,8)
                THEN 3

                WHEN dd.Month IN (9,10,11)
                THEN 4
            END AS "Season Number",

            ------------------------------------------------
            -- Season name
            ------------------------------------------------

            CASE
                WHEN dd.Month IN (12,1,2)
                THEN 'Winter'

                WHEN dd.Month IN (3,4,5)
                THEN 'Spring'

                WHEN dd.Month IN (6,7,8)
                THEN 'Summer'

                WHEN dd.Month IN (9,10,11)
                THEN 'Fall'
            END AS "Season",

            ------------------------------------------------
            -- Service-day category
            ------------------------------------------------

            CASE
                WHEN dd.DayName IN (
                    'Monday',
                    'Tuesday',
                    'Wednesday',
                    'Thursday',
                    'Friday'
                )
                THEN 'Weekday'

                WHEN dd.DayName = 'Saturday'
                THEN 'Saturday'

                WHEN dd.DayName = 'Sunday'
                THEN 'Sunday'
            END AS "Service Day Category",

            r.RouteShortName AS "Route Short Name",
            r.RouteName AS "Route Name",
            d.DirectionName AS "Direction",
            tp.TripName AS "Trip",

            tp.TotalCount AS "Passenger Load",

            DATEDIFF(
                SECOND,
                tp.ScheduleArriveTime,
                tp.ActualArriveTime
            ) AS "Arrive Delta Seconds",

            DATEDIFF(
                SECOND,
                tp.ScheduleDepartTime,
                tp.ActualDepartTime
            ) AS "Depart Delta Seconds"

        FROM VehicleLocationTP tp

        INNER JOIN DateDimension dd
            ON tp.ActualArriveDateKey =
               dd.DateDimensionKey

        INNER JOIN sch_Route r
            ON tp.RouteKey =
               r.RouteKey

        INNER JOIN sch_Pattern p
            ON tp.PatternKey =
               p.PatternKey

        INNER JOIN sch_Direction d
            ON p.DirectionKey =
               d.DirectionKey

        WHERE
            dd.FullDate >= CAST(
                '2025-12-01' AS DATETIME
            )

            AND dd.FullDate < CAST(
                '2027-01-01' AS DATETIME
            )

            AND r.RouteShortName IN (
                '1','10','123','123s','170',
                '2','20','225','240','25',
                '26','26s','27','3','40',
                '41','42','47','48','50',
                '64','65','67','68'
            )

            AND tp.TotalCount IS NOT NULL

            AND tp.ActualArriveTime IS NOT NULL

            AND tp.ScheduleArriveTime IS NOT NULL

            AND tp.InBetween <> 1

    ) x
) y

GROUP BY
    y."Season Year",
    y."Season Number",
    y."Season",
    y."Service Day Category",
    y."Route Short Name",
    y."Route Name",
    y."Direction",
    y."Trip"

) apc

LEFT JOIN (

------------------------------------------------------------
-- FARE DATA
-- Average daily boardings, total fare counts, and fare days
------------------------------------------------------------

SELECT
    fare_daily."Season Year",
    fare_daily."Season Number",
    fare_daily."Season",
    fare_daily."Service Day Category",
    fare_daily."Route Short Name",
    fare_daily."Route Name",
    fare_daily."Direction",
    fare_daily."Trip",

    ROUND(
        CAST(
            SUM(fare_daily."Daily Fare Counts")
            AS DECIMAL(18,2)
        )
        /
        NULLIF(
            MAX(
                service_days."Observed Service Days"
            ),
            0
        ),
        1
    ) AS "Average Daily Boardings",

    SUM(
        fare_daily."Daily Fare Counts"
    ) AS "Total Fare Counts",

    COUNT(*) AS "Fare Service Days"

FROM (

    --------------------------------------------------------
    -- Calculate fare boardings for each service date
    --------------------------------------------------------

    SELECT
        CASE
            WHEN dd.Month = 12
            THEN dd.Year + 1
            ELSE dd.Year
        END AS "Season Year",

        CASE
            WHEN dd.Month IN (12,1,2)
            THEN 1

            WHEN dd.Month IN (3,4,5)
            THEN 2

            WHEN dd.Month IN (6,7,8)
            THEN 3

            WHEN dd.Month IN (9,10,11)
            THEN 4
        END AS "Season Number",

        CASE
            WHEN dd.Month IN (12,1,2)
            THEN 'Winter'

            WHEN dd.Month IN (3,4,5)
            THEN 'Spring'

            WHEN dd.Month IN (6,7,8)
            THEN 'Summer'

            WHEN dd.Month IN (9,10,11)
            THEN 'Fall'
        END AS "Season",

        CAST(
            dd.FullDate AS DATE
        ) AS "Service Date",

        CASE
            WHEN dd.DayName IN (
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday'
            )
            THEN 'Weekday'

            WHEN dd.DayName = 'Saturday'
            THEN 'Saturday'

            WHEN dd.DayName = 'Sunday'
            THEN 'Sunday'
        END AS "Service Day Category",

        r.RouteShortName AS "Route Short Name",
        r.RouteName AS "Route Name",
        d.DirectionName AS "Direction",
        tp.TripName AS "Trip",

        SUM(
            vf.FareCount
        ) AS "Daily Fare Counts"

    FROM DateDimension dd

    INNER JOIN VehicleLocationTPFare vf
        ON dd.DateDimensionKey =
           vf.EventDateKey

    INNER JOIN sch_WorkItemCompleted wic
        ON wic.WorkItemCompletedKey =
           vf.WorkItemCompletedKey

    INNER JOIN VehicleLocationTP tp
        ON tp.VehicleLocationTPKey =
           vf.VehicleLocationTPKey

    INNER JOIN sch_Route r
        ON r.RouteKey =
           wic.RouteKey

    INNER JOIN sch_Pattern p
        ON p.PatternKey =
           tp.PatternKey

    INNER JOIN sch_Direction d
        ON d.DirectionKey =
           p.DirectionKey

    WHERE
        dd.FullDate >= CAST(
            '2025-12-01' AS DATETIME
        )

        AND dd.FullDate < CAST(
            '2027-01-01' AS DATETIME
        )

        AND vf.FareTypeKey NOT IN (
            9,11,14,20
        )

        AND r.RouteShortName IN (
            '1','10','123','123s','170',
            '2','20','225','240','25',
            '26','26s','27','3','40',
            '41','42','47','48','50',
            '64','65','67','68'
        )

        AND vf.FareCount IS NOT NULL

    GROUP BY
        CASE
            WHEN dd.Month = 12
            THEN dd.Year + 1
            ELSE dd.Year
        END,

        CASE
            WHEN dd.Month IN (12,1,2)
            THEN 1

            WHEN dd.Month IN (3,4,5)
            THEN 2

            WHEN dd.Month IN (6,7,8)
            THEN 3

            WHEN dd.Month IN (9,10,11)
            THEN 4
        END,

        CASE
            WHEN dd.Month IN (12,1,2)
            THEN 'Winter'

            WHEN dd.Month IN (3,4,5)
            THEN 'Spring'

            WHEN dd.Month IN (6,7,8)
            THEN 'Summer'

            WHEN dd.Month IN (9,10,11)
            THEN 'Fall'
        END,

        CAST(
            dd.FullDate AS DATE
        ),

        CASE
            WHEN dd.DayName IN (
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday'
            )
            THEN 'Weekday'

            WHEN dd.DayName = 'Saturday'
            THEN 'Saturday'

            WHEN dd.DayName = 'Sunday'
            THEN 'Sunday'
        END,

        r.RouteShortName,
        r.RouteName,
        d.DirectionName,
        tp.TripName

) fare_daily

LEFT JOIN (

    --------------------------------------------------------
    -- Count distinct dates each route-direction-trip was
    -- observed operating in VehicleLocationTP
    --------------------------------------------------------

    SELECT
        CASE
            WHEN dd_service.Month = 12
            THEN dd_service.Year + 1
            ELSE dd_service.Year
        END AS "Season Year",

        CASE
            WHEN dd_service.Month IN (12,1,2)
            THEN 1

            WHEN dd_service.Month IN (3,4,5)
            THEN 2

            WHEN dd_service.Month IN (6,7,8)
            THEN 3

            WHEN dd_service.Month IN (9,10,11)
            THEN 4
        END AS "Season Number",

        CASE
            WHEN dd_service.Month IN (12,1,2)
            THEN 'Winter'

            WHEN dd_service.Month IN (3,4,5)
            THEN 'Spring'

            WHEN dd_service.Month IN (6,7,8)
            THEN 'Summer'

            WHEN dd_service.Month IN (9,10,11)
            THEN 'Fall'
        END AS "Season",

        CASE
            WHEN dd_service.DayName IN (
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday'
            )
            THEN 'Weekday'

            WHEN dd_service.DayName = 'Saturday'
            THEN 'Saturday'

            WHEN dd_service.DayName = 'Sunday'
            THEN 'Sunday'
        END AS "Service Day Category",

        r_service.RouteShortName AS "Route Short Name",
        r_service.RouteName AS "Route Name",
        d_service.DirectionName AS "Direction",
        tp_service.TripName AS "Trip",

        COUNT(
            DISTINCT CAST(
                dd_service.FullDate AS DATE
            )
        ) AS "Observed Service Days"

    FROM VehicleLocationTP tp_service

    INNER JOIN DateDimension dd_service
        ON tp_service.ActualArriveDateKey =
           dd_service.DateDimensionKey

    INNER JOIN sch_Route r_service
        ON tp_service.RouteKey =
           r_service.RouteKey

    INNER JOIN sch_Pattern p_service
        ON tp_service.PatternKey =
           p_service.PatternKey

    INNER JOIN sch_Direction d_service
        ON p_service.DirectionKey =
           d_service.DirectionKey

    WHERE
        dd_service.FullDate >= CAST(
            '2025-12-01' AS DATETIME
        )

        AND dd_service.FullDate < CAST(
            '2027-01-01' AS DATETIME
        )

        AND r_service.RouteShortName IN (
            '1','10','123','123s','170',
            '2','20','225','240','25',
            '26','26s','27','3','40',
            '41','42','47','48','50',
            '64','65','67','68'
        )

        AND tp_service.TripName IS NOT NULL

        AND tp_service.InBetween <> 1

    GROUP BY
        CASE
            WHEN dd_service.Month = 12
            THEN dd_service.Year + 1
            ELSE dd_service.Year
        END,

        CASE
            WHEN dd_service.Month IN (12,1,2)
            THEN 1

            WHEN dd_service.Month IN (3,4,5)
            THEN 2

            WHEN dd_service.Month IN (6,7,8)
            THEN 3

            WHEN dd_service.Month IN (9,10,11)
            THEN 4
        END,

        CASE
            WHEN dd_service.Month IN (12,1,2)
            THEN 'Winter'

            WHEN dd_service.Month IN (3,4,5)
            THEN 'Spring'

            WHEN dd_service.Month IN (6,7,8)
            THEN 'Summer'

            WHEN dd_service.Month IN (9,10,11)
            THEN 'Fall'
        END,

        CASE
            WHEN dd_service.DayName IN (
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday'
            )
            THEN 'Weekday'

            WHEN dd_service.DayName = 'Saturday'
            THEN 'Saturday'

            WHEN dd_service.DayName = 'Sunday'
            THEN 'Sunday'
        END,

        r_service.RouteShortName,
        r_service.RouteName,
        d_service.DirectionName,
        tp_service.TripName

) service_days

ON fare_daily."Season Year" =
   service_days."Season Year"

AND fare_daily."Season Number" =
    service_days."Season Number"

AND fare_daily."Season" =
    service_days."Season"

AND fare_daily."Service Day Category" =
    service_days."Service Day Category"

AND fare_daily."Route Short Name" =
    service_days."Route Short Name"

AND fare_daily."Direction" =
    service_days."Direction"

AND fare_daily."Trip" =
    service_days."Trip"

GROUP BY
    fare_daily."Season Year",
    fare_daily."Season Number",
    fare_daily."Season",
    fare_daily."Service Day Category",
    fare_daily."Route Short Name",
    fare_daily."Route Name",
    fare_daily."Direction",
    fare_daily."Trip"

) fare

ON apc."Season Year" =fare."Season Year"

AND apc."Season Number" =fare."Season Number"

AND apc."Season" =fare."Season"

AND apc."Service Day Category" =fare."Service Day Category"

AND apc."Route Short Name" =fare."Route Short Name"

AND apc."Direction" =fare."Direction"

AND apc."Trip" =fare."Trip"
