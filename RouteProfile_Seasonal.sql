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
        fare."Fare Service Days",
        0
    ) AS "Fare Service Days",

    apc."Median Passenger Load",

    apc."On Time Arrivals",

    ROUND(
        100.0 * apc."On Time Arrivals"
        / NULLIF(apc."Total Arrival Events", 0),
        1
    ) AS "% On Time",

    apc."Early Arrivals",

    ROUND(
        100.0 * apc."Early Arrivals"
        / NULLIF(apc."Total Arrival Events", 0),
        1
    ) AS "% Early",

    apc."Late Arrivals",

    ROUND(
        100.0 * apc."Late Arrivals"
        / NULLIF(apc."Total Arrival Events", 0),
        1
    ) AS "% Late"

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

        COUNT(*) AS "Total Arrival Events"

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
                    WHEN dd.Month IN (12, 1, 2)
                    THEN 1

                    WHEN dd.Month IN (3, 4, 5)
                    THEN 2

                    WHEN dd.Month IN (6, 7, 8)
                    THEN 3

                    WHEN dd.Month IN (9, 10, 11)
                    THEN 4
                END AS "Season Number",

                ------------------------------------------------
                -- Season name
                ------------------------------------------------
                CASE
                    WHEN dd.Month IN (12, 1, 2)
                    THEN 'Winter'

                    WHEN dd.Month IN (3, 4, 5)
                    THEN 'Spring'

                    WHEN dd.Month IN (6, 7, 8)
                    THEN 'Summer'

                    WHEN dd.Month IN (9, 10, 11)
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
                ) AS "Arrive Delta Seconds"

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
    -- Average daily boardings based entirely on fare counts
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
            AVG(
                CAST(
                    fare_daily."Daily Fare Counts"
                    AS DECIMAL(18,2)
                )
            ),
            1
        ) AS "Average Daily Boardings",

        COUNT(*) AS "Fare Service Days"

    FROM (
        --------------------------------------------------------
        -- Calculate boardings for each individual service date
        --------------------------------------------------------
        SELECT
            CASE
                WHEN dd.Month = 12
                THEN dd.Year + 1
                ELSE dd.Year
            END AS "Season Year",

            CASE
                WHEN dd.Month IN (12, 1, 2)
                THEN 1

                WHEN dd.Month IN (3, 4, 5)
                THEN 2

                WHEN dd.Month IN (6, 7, 8)
                THEN 3

                WHEN dd.Month IN (9, 10, 11)
                THEN 4
            END AS "Season Number",

            CASE
                WHEN dd.Month IN (12, 1, 2)
                THEN 'Winter'

                WHEN dd.Month IN (3, 4, 5)
                THEN 'Spring'

                WHEN dd.Month IN (6, 7, 8)
                THEN 'Summer'

                WHEN dd.Month IN (9, 10, 11)
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
                WHEN dd.Month IN (12, 1, 2)
                THEN 1

                WHEN dd.Month IN (3, 4, 5)
                THEN 2

                WHEN dd.Month IN (6, 7, 8)
                THEN 3

                WHEN dd.Month IN (9, 10, 11)
                THEN 4
            END,

            CASE
                WHEN dd.Month IN (12, 1, 2)
                THEN 'Winter'

                WHEN dd.Month IN (3, 4, 5)
                THEN 'Spring'

                WHEN dd.Month IN (6, 7, 8)
                THEN 'Summer'

                WHEN dd.Month IN (9, 10, 11)
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

    ON apc."Season Year" =
       fare."Season Year"

    AND apc."Season Number" =
        fare."Season Number"

    AND apc."Season" =
        fare."Season"

    AND apc."Service Day Category" =
        fare."Service Day Category"

    AND apc."Route Short Name" =
        fare."Route Short Name"

    AND apc."Direction" =
        fare."Direction"

    AND apc."Trip" =
        fare."Trip"
