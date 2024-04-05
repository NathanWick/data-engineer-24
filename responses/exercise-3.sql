/*
OBJECTIVE: Clean table-history and status-changes tables
		   to create joinable tables to create a dataset 
		   that resembles:

| customer_id | start_date | end_date | end_reason |
| --- | --- | --- | --- |
| 1618630 | 2020-07-15 | 2020-08-16 | expire |
| 1618630 | 2021-03-22 | 2021-05-23 | expire |
| 1634015 | 2021-08-07 | 2021-11-01 | freeze |
| 1634015 | 2021-11-24 | 2022-02-01 | freeze |
| 1634015 | 2022-04-01 | 2022-07-01 | cancel |
| 1634015 | 2022-09-26 | 2022-11-01 | cancel |
*/

-- Make new temp table for status_changes
DROP TABLE IF EXISTS temp_status_changes;
CREATE TEMPORARY TABLE temp_status_changes AS
SELECT * FROM status_changes;

-- Make new temp table for table history
DROP TABLE IF EXISTS temp_table_history;
CREATE TEMPORARY TABLE temp_table_history AS
SELECT * FROM table_history;

-- Add additional columns for converted datetimes
ALTER TABLE temp_status_changes
ADD COLUMN clean_postdate DATETIME,
ADD COLUMN clean_start_date DATETIME;

-- Add additional columns for converted datetime
ALTER TABLE temp_table_history
ADD COLUMN clean_postdate DATETIME;

-- Convert text date to datetime
UPDATE temp_status_changes
SET clean_postdate = STR_TO_DATE(TRIM(BOTH '"' FROM postdate), '%Y-%m-%d %H:%i:%s');

-- Convert text date to datetime
UPDATE temp_status_changes
SET clean_start_date = STR_TO_DATE(TRIM(BOTH '"' FROM start_date), '%Y-%m-%d %H:%i:%s');

-- Convert text date to datetime
UPDATE temp_table_history
SET clean_postdate = STR_TO_DATE(TRIM(BOTH '"' FROM postdate), '%Y-%m-%d %H:%i:%s');

-- Trim outter quotes from changes column
UPDATE temp_table_history
SET changes = TRIM(BOTH '"' FROM changes);

-- Split each attribute in changes column into a new row using cross join and split on '@#@#@#'
DROP TABLE IF EXISTS temp_table_history_split;
CREATE TEMPORARY TABLE temp_table_history_split AS
SELECT table_history_id, customer_id, clean_postdate AS postdate,
	   SUBSTRING_INDEX(SUBSTRING_INDEX(changes, '@#@#@#', numbers.n), '@#@#@#', -1) AS changes
FROM temp_table_history
CROSS JOIN (
	SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8
) numbers
WHERE numbers.n <= 1 + (LENGTH(changes) - LENGTH(REPLACE(changes, '@#@#@#', '')))
  AND LENGTH(SUBSTRING_INDEX(SUBSTRING_INDEX(changes, '@#@#@#', numbers.n), '@#@#@#', -1)) > 0;

-- Split each attribute, old value, and new value into new columns split on '-^!^!^-'
DROP TABLE IF EXISTS temp_table_history_normalized;
CREATE TEMPORARY TABLE temp_table_history_normalized AS
SELECT
	table_history_id,customer_id,postdate,
	SUBSTRING_INDEX(SUBSTRING_INDEX(changes, '-^!^!^-', 1), '-^!^!^-', -1) AS attribute,
	SUBSTRING_INDEX(SUBSTRING_INDEX(changes, '-^!^!^-', 2), '-^!^!^-', -1) AS old_value,
	SUBSTRING_INDEX(changes, '-^!^!^-', -1) AS new_value
FROM
	temp_table_history_split;

-- Select all membership start and end records.
-- Ensure we only get 1 customer record for any given time
DROP TABLE IF EXISTS temp_table_history_membership_records;
CREATE TEMPORARY TABLE temp_table_history_membership_records AS
SELECT customer_id, postdate,
	   MAX(table_history_id) AS max_table_history_id
FROM temp_table_history_normalized
WHERE attribute IN ('membership_start_date','membership_exp_date')
  AND new_value <> '0000-00-00'
GROUP BY customer_id, postdate;

-- Pull all table history records filter to membership_records set.
DROP TABLE IF EXISTS temp_table_history_membership_end;
CREATE TEMPORARY TABLE temp_table_history_membership_end AS
SELECT a.customer_id, a.postdate AS postdate,
	   MAX(CASE WHEN attribute = 'membership_start_date' THEN new_value END) AS start_date,
	   MAX(CASE WHEN attribute = 'membership_exp_date' THEN new_value END) AS exp_date,
	   MAX(CASE WHEN attribute = 'current_status' THEN new_value END) AS current_status -- SELECT *
FROM temp_table_history_normalized a
	INNER JOIN temp_table_history_membership_records b ON a.table_history_id = b.max_table_history_id
GROUP BY a.customer_id, a.postdate
ORDER BY postdate;

-- Join member records with status changes to determine end_reason
-- Assume expired if exp date in past (may be unnecessary) 
SELECT a.customer_id, a.start_date, a.exp_date AS end_date,
       CASE WHEN (CASE WHEN b.status IS NULL THEN a.current_status ELSE b.status END) = 'OK' AND exp_date < NOW() 
			THEN 'EXPIRE' 
            ELSE (CASE WHEN b.status IS NULL THEN a.current_status ELSE b.status END) END AS end_reason
FROM temp_table_history_membership_end a
	LEFT JOIN temp_status_changes b ON a.customer_id = b.customer_id 
		  AND a.start_date <= b.clean_start_date
		  AND a.exp_date >= b.clean_start_date
GROUP BY a.customer_id, a.start_date, a.exp_date, a.current_status, 
		 b.clean_start_date, b.status
ORDER BY a.customer_id, a.start_date, b.clean_start_date;