-- In our work we will use the financial database,
-- which contains information about loans that have been repaid or not.

/*History of loans granted
summary of granted loans in the following dimensions:
    year, quarter, month,
    year, quarter
    year,
    total.
As a result of the summary, display the following information:
total amount of loans, average amount of loans, total number of loans granted.*/

SELECT COUNT(loan_id) AS loan_count,
       SUM(amount)AS loan_sum,
       AVG(amount) AS avg_loan,
       EXTRACT(YEAR FROM date) AS loan_year,
       EXTRACT(QUARTER FROM date) AS loan_quarter,
       EXTRACT(MONTH FROM date) AS loan_month
FROM loan
GROUP BY  loan_year, loan_quarter, loan_month
WITH ROLLUP
ORDER BY 4,5,6;

/*Loan status
Write a query with which you try to answer the question which statuses indicate repaid loans,
and which statuses indicate loans that have not been repaid (there are a total of 682 loans in the database,
 of which 606 have been repaid and 76 have not been repaid).*/
SELECT status,
       COUNT(loan_id)
FROM loan
GROUP BY status;  -- A and C repaid, B and D not repaid

/*Analysis of accounts
Write a query that ranks accounts according to the following criteria:
number of loans granted (descending),
amount of loans granted (descending),
average loan amount.
Only repaid loans are taken into account.*/
SELECT account_id,
       COUNT(loan_id) AS loan_count,
       SUM(amount) AS loan_sum,
       AVG(amount) AS avg_loan
    FROM loan
    WHERE status IN ('A','C')
    GROUP BY account_id
    ORDER BY loan_count DESC, loan_sum DESC, avg_loan;  -- the loan table is sufficient, as we have the account_id here and this is sufficient to rank the accounts

/*Loans repaid
Check the balance of loans repaid by customer gender.
In addition, check in the manner of your choice whether the query is correct.*/
SELECT
    c.gender,
    SUM(l.amount) AS saldo
    FROM loan l
INNER JOIN disp d ON l.account_id = d.account_id -- you can also: USING(account_id)
INNER JOIN client c ON d.client_id = c.client_id
WHERE l.status IN ('A', 'C')
GROUP BY c.gender;

-- check
DROP TABLE IF EXISTS tmp_result;
CREATE TEMPORARY TABLE tmp_result AS(SELECT
    c.gender,
    SUM(l.amount) AS saldo
    FROM loan l
INNER JOIN disp d ON l.account_id = d.account_id
INNER JOIN client c ON d.client_id = c.client_id
WHERE l.status IN ('A', 'C')
GROUP BY c.gender);

-- I check the balance in my question and only from the loan (omitting the account table)
WITH cte AS (
    SELECT SUM(amount) as amount
    FROM loan as l
    WHERE status IN('A', 'C')
)
SELECT (SELECT SUM(saldo) FROM tmp_result) - (SELECT amount from cte); -- nie wyszło zero!;
-- sprawdzam ilość account_id poszczególnych w disp:
SELECT disp.account_id, COUNT(disp.account_id) FROM disp GROUP BY account_id ORDER BY count(account_id) DESC;
SELECT * FROM disp WHERE account_id = 1095; -- 2 different client IDs, one OWNER, one DISPONENT

-- you have to add a condition about the owner of the account to the query though
DROP TABLE IF EXISTS tmp_result;
CREATE TEMPORARY TABLE tmp_result AS(SELECT
    c.gender,
    SUM(l.amount) AS saldo
    FROM loan l
INNER JOIN disp d ON l.account_id = d.account_id
INNER JOIN client c ON d.client_id = c.client_id
WHERE l.status IN ('A', 'C')
AND d.type = 'OWNER'
GROUP BY c.gender);

WITH cte AS (
    SELECT SUM(amount) as amount
    FROM loan as l
    WHERE status IN('A', 'C')
)
SELECT (SELECT SUM(saldo) FROM tmp_result) - (SELECT amount from cte); -- wyszło 0
/*Analiza klienta cz. 1
 Modyfikując zapytania z zadania dot. spłaconych pożyczek, odpowiedz na poniższe pytania:
  - kto posiada więcej spłaconych pożyczek – kobiety czy mężczyźni?
  - jaki jest średni wiek kredytobiorcy w zależności od płci?*/
DROP TABLE IF EXISTS tmp_client_analysis;
CREATE TEMPORARY TABLE tmp_client_analysis AS (
SELECT
    c.gender,
    2021 - EXTRACT(YEAR FROM c.birth_date) AS age,
    SUM(l.amount) AS saldo,
    COUNT(l.amount) AS loan_count
    FROM loan l
INNER JOIN disp d ON l.account_id = d.account_id -- or USING(account_id)
INNER JOIN client c ON d.client_id = c.client_id
WHERE l.status IN ('A', 'C')
AND d.type = 'OWNER'
GROUP BY c.gender, 2);  -- you need to add a second column to the group by

-- answering questions
SELECT gender,
       AVG(age),
       SUM(loan_count)
FROM tmp_client_analysis
GROUP BY gender;

SELECT * FROM tmp_client_analysis; -- check - 88 rows

-- year of birth of the borrower
SELECT EXTRACT(YEAR FROM birth_date) AS birth_year
FROM client;*/
-- average age of the borrower
SELECT AVG(2021 - EXTRACT(YEAR FROM c.birth_date)) FROM client c;*/

 /* Customer analysis part 2
 Make analyses that answer the questions:
  - in which area are the most clients, -- clirnts
  - in which area the most loans were repaid in terms of volume, -- loan_count
  - in which area the most loans were repaid in total -- loan_saldo
 Select only account holders as customers.*/
SELECT
    A2 as district_name,
    COUNT(l.account_id) AS clients,
    SUM(l.amount) AS loan_saldo,
    COUNT(l.loan_id) AS loan_count
FROM loan l
INNER JOIN disp d ON l.account_id = d.account_id -- or USING(account_id)
INNER JOIN client c ON d.client_id = c.client_id
INNER JOIN district ds ON c.district_id = ds.district_id
WHERE l.status IN ('A', 'C')
AND d.type = 'OWNER'
GROUP BY c.district_id
ORDER BY loan_count DESC;  -- 76 rows

/* Customer analysis part 3
 Using the query obtained in the previous task, modify it so,
 to determine the percentage share of each region in the total amount of loans granted.
 In other words, the aim is to determine the distribution of loans granted by region. */
WITH l_stats AS (
SELECT
    A2 as district_name,
    COUNT(l.account_id) AS clients_count,
    SUM(l.amount) AS loan_saldo,
    COUNT(l.loan_id) AS loan_count
FROM loan l
INNER JOIN disp d ON l.account_id = d.account_id -- or USING(account_id)
INNER JOIN client c ON d.client_id = c.client_id
INNER JOIN district ds ON c.district_id = ds.district_id
WHERE l.status IN ('A', 'C')
AND d.type = 'OWNER'
GROUP BY c.district_id
ORDER BY loan_count DESC
)
SELECT *,
       SUM(loan_saldo) OVER () AS total_saldo,
       (loan_saldo / SUM(loan_saldo) OVER ()) AS percentage_of_total
        FROM l_stats
ORDER BY percentage_of_total DESC;

/* Selection part 1# 
Check that there are customers in the database who meet the following conditions:
  - have an account balance of more than 1,000,
  - have more than five loans,
  - were born after 1990.
 Whereby we assume that the account balance is the amount of the loan - deposits */
SELECT
    c.client_id,
    SUM(l.amount) AS loan_amount,  -- change the name to amount
    COUNT(l.loan_id) AS loan_count,
    (SUM(l.amount) - SUM(payments)) AS saldo_konta
FROM loan l
INNER JOIN disp d ON l.account_id = d.account_id -- or USING(account_id)
INNER JOIN client c ON d.client_id = c.client_id
WHERE l.status IN ('A', 'C')
AND d.type = 'OWNER'
AND birth_date > '1990-12-31'
GROUP BY c.client_id
HAVING saldo_konta > 1000 AND loan_count > 5;  -- we have an empty result set

-- attempt to rewrite
SELECT
    client_id
FROM client c
WHERE birth_date > '1990-12-31';  -- there are no clients born after 1990

SELECT
    c.client_id,
    COUNT(loan_id)
FROM client c
INNER JOIN disp d on c.client_id = d.client_id
INNER JOIN loan l ON d.account_id = l.account_id
WHERE d.type = 'OWNER'
GROUP BY c.client_id
ORDER BY COUNT(loan_id) DESC; -- no clients with more than one loan

SELECT DISTINCT
    c.client_id,
    SUM(l.amount),
    SUM(payments),
    (SUM(l.amount) - SUM(payments)) AS saldo_konta
FROM client c
INNER JOIN disp d on c.client_id = d.client_id
INNER JOIN loan l ON d.account_id = l.account_id
WHERE d.type = 'OWNER' AND l.status IN ('A', 'C')
GROUP BY c.client_id
HAVING (SUM(l.amount) - SUM(payments)) > 1000; -- 606 rows
-- in this way, questions can be answered with simpler queries...

/* Selection part 2
 From the previous task, you probably already know that there are no customers who met the required criteria.
 Perform an analysis with which you determine which condition caused the lack of results. */
SELECT
    c.client_id,
    SUM(l.amount) AS loan_amount,  -- change the name to amount
    COUNT(l.loan_id) AS loan_count,
    (SUM(l.amount) - SUM(payments)) AS saldo_konta
FROM loan l
INNER JOIN disp d ON l.account_id = d.account_id -- or USING(account_id)
INNER JOIN client c ON d.client_id = c.client_id
WHERE l.status IN ('A', 'C')
AND d.type = 'OWNER'
# AND birth_date > '1990-12-31' -- no clients born after 1990
GROUP BY c.client_id
HAVING saldo_konta > 1000
#    AND loan_count > 5 -- no clients with more than 1 loan
ORDER BY loan_count DESC; -- 606 wierszy

/* Expiring cards
 Write a procedure that will refresh the table you have created (you can call it cards_at_expiration, for example)
 containing the following columns:
  - customer id,
  - id_card,
 expiry date - assume the card can be active for 3 years after issue,
 customer address (column A3 is sufficient).
 Note: The card table includes cards that were issued up to the end of 1998.*/

-- first of all, the query
SELECT cl.client_id,
       c.card_id,
       ADDDATE(c.issued, INTERVAL 3 YEAR ) AS expiration_date,
       dst.A3 AS client_region
FROM client cl
INNER JOIN district dst ON cl.district_id = dst.district_id
INNER JOIN disp d ON cl.client_id = d.client_id
INNER JOIN card c ON d.disp_id = c.disp_id;

-- you have to create a table: - we cannot create a table in the database, so I make a temporary one
CREATE TEMPORARY TABLE tmp_cards_at_expiration
(
    client_id       int                      not null,
    card_id         int default 0            not null,
    expiration_date date                     null,
    A3              varchar(15) charset utf8 not null,
    generated_for_date date                     null
);

-- according to the solution, queries searching for cards that expire in 7 days from a given date should be added to the querier
WITH card_stats AS(
    SELECT cl.client_id,
       c.card_id,
       ADDDATE(c.issued, INTERVAL 3 YEAR ) AS expiration_date,
       dst.A3 AS client_region
       -- here to add on when generated
FROM client cl
INNER JOIN district dst ON cl.district_id = dst.district_id
INNER JOIN disp d ON cl.client_id = d.client_id
INNER JOIN card c ON d.disp_id = c.disp_id
)
SELECT * FROM card_stats
WHERE expiration_date BETWEEN ADDDATE(input_date, INTERVAL -7 DAY) AND input_date;

-- we create the procedure
DELIMITER $$
DROP PROCEDURE IF EXISTS generate_expiration_report;
CREATE PROCEDURE generate_expiration_report(IN input_date DATE)
BEGIN
   TRUNCATE tmp_cards_at_expiration;
   INSERT INTO tmp_cards_at_expiration
       WITH card_stats AS(
        SELECT cl.client_id,
            c.card_id,
            ADDDATE(c.issued, INTERVAL 3 YEAR ) AS expiration_date,
            dst.A3 AS client_region,
            input_date AS generated_for_date
        FROM client cl
        INNER JOIN district dst ON cl.district_id = dst.district_id
        INNER JOIN disp d ON cl.client_id = d.client_id
        INNER JOIN card c ON d.disp_id = c.disp_id
        )
    SELECT * FROM card_stats
    WHERE expiration_date BETWEEN ADDDATE(input_date, INTERVAL -7 DAY) AND input_date;
END $$
DELIMITER ;

CALL generate_expiration_report('2000-05-18');
CALL generate_expiration_report('2000-07-26');
SELECT * FROM tmp_cards_at_expiration;