-- Normalize transactions to create a joinable table to orderItems
WITH normalized_transactions AS (
  SELECT
    a.type,
    a.datetime,
    CAST(j.item ->> '$.id' AS UNSIGNED) AS item_id,
    CAST(j.item ->> '$.amount' AS DECIMAL(10,2)) AS item_amount -- SELECT * 
  FROM
    transactions a
    CROSS JOIN JSON_TABLE(
      a.details,
      '$.items[*]' COLUMNS (
        item JSON PATH '$'
      )
    ) j
)
    SELECT 
    locationId,
    DATE_FORMAT(datetime, '%Y%m') AS YEARMONTH,
    SUM(item_amount) AS REFUND_AMT
FROM 
    normalized_transactions j
LEFT JOIN 
    orderItems o ON j.item_id = o.id
WHERE 
    j.type = 'refund'
GROUP BY
    locationId, DATE_FORMAT(datetime, '%Y%m')
ORDER BY
    locationId, DATE_FORMAT(datetime, '%Y%m');

-- ---- SANITY CHECK ---- --

-- Normalize transactions to create a joinable table to orderItems
WITH normalized_transactions AS (
  SELECT
    a.type,
    a.datetime,
    CAST(j.item ->> '$.id' AS UNSIGNED) AS item_id,
    CAST(j.item ->> '$.amount' AS DECIMAL(10,2)) AS item_amount -- SELECT * 
  FROM
    transactions a
    CROSS JOIN JSON_TABLE(
      a.details,
      '$.items[*]' COLUMNS (
        item JSON PATH '$'
      )
    ) j
)

-- Join to orderItems table on id and group by location & year-month
SELECT item_id, locationId, 
	   datetime,
	   SUM(item_amount) AS REFUND_AMT, 
	   SUM(salesAmount) AS SALES_AMT, 
	   SUM(salesAmount)-SUM(item_amount) AS BALANCE
FROM normalized_transactions j
	LEFT JOIN orderItems o ON j.item_id = o.id
WHERE j.type = 'refund' 
GROUP BY 
    item_id, locationId, datetime
HAVING SUM(item_amount) <> SUM(salesAmount)
ORDER BY 
    item_id, locationId, datetime;