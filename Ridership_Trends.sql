SELECT
    CAST(dd.Year AS VARCHAR(4)) AS "Year",
    dd.Month AS "Month Number",
    dd.MonthName AS "Month",

    CAST(dd.Year AS VARCHAR(4))
        + '-'
        + RIGHT('0' + CAST(dd.Month AS VARCHAR(2)), 2)
        AS "Year-Month",

    r.RouteShortName AS "Route Short Name",
    r.RouteName AS "Route Name",

    SUM(fc.FareCount) AS "Total Fare Counts"

FROM
(
    SELECT
        vf.EventDateKey,
        vf.WorkItemCompletedKey,
        vf.FareTypeKey,
        MAX(vf.FareCount) AS FareCount

    FROM VehicleLocationTPFare vf

    WHERE
        vf.FareCount IS NOT NULL
        AND vf.FareTypeKey NOT IN (9, 11, 14, 20)

    GROUP BY
        vf.EventDateKey,
        vf.WorkItemCompletedKey,
        vf.FareTypeKey
) fc

INNER JOIN DateDimension dd
    ON dd.DateDimensionKey = fc.EventDateKey

INNER JOIN sch_WorkItemCompleted wic
    ON wic.WorkItemCompletedKey = fc.WorkItemCompletedKey

INNER JOIN sch_Route r
    ON r.RouteKey = wic.RouteKey

WHERE
    dd.FullDate >= CAST('2023-01-01' AS DATETIME)

    AND dd.FullDate < DATEADD(
        day,
        1,
        CAST(GETDATE() AS DATE)
    )

    AND r.RouteShortName IN
    (
        '1', '10', '123', '123s', '170',
        '2', '20', '225', '240', '25',
        '26', '26s', '27', '3', '40',
        '41', '42', '47', '48', '50',
        '64', '65', '67', '68'
    )

GROUP BY
    dd.Year,
    dd.Month,
    dd.MonthName,
    r.RouteShortName,
    r.RouteName
