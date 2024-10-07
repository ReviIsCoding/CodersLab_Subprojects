# W pracy będziemy korzystać z bazy danych financial,
# która zawiera informacje o pożyczkach, które zostały spłacone lub nie.

/*Historia udzielanych kredytów
podsumowanie z udzielanych kredytów w następujących wymiarach:
    rok, kwartał, miesiąc,
    rok, kwartał,
    rok,
    sumarycznie.
Jako wynik podsumowania wyświetl następujące informacje:
sumaryczna kwota pożyczek, średnia kwota pożyczki, całkowita liczba udzielonych pożyczek.*/

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

/*Status pożyczki
napisz kwerendę, za pomocą której spróbujesz odpowiedzieć na pytanie, które statusy oznaczają pożyczki spłacone,
a które oznaczają pożyczki niespłacone (w bazie znajdują się w sumie 682 udzielone kredyty, z czego 606 zostało spłaconych, a 76 nie.)*/
SELECT status,
       COUNT(loan_id)
FROM loan
GROUP BY status;  -- A i C spłacone, B i D niespłacone

/*Analiza kont
Napisz kwerendę, która uszereguje konta według następujących kryteriów:
liczba udzielonych pożyczek (malejąco),
kwota udzielonych pożyczek (malejąco),
średnia kwota pożyczki.
Pod uwagę bierzemy tylko spłacone pożyczki*/
SELECT account_id,
       COUNT(loan_id) AS loan_count,
       SUM(amount) AS loan_sum,
       AVG(amount) AS avg_loan
    FROM loan
    WHERE status IN ('A','C')
    GROUP BY account_id
    ORDER BY loan_count DESC, loan_sum DESC, avg_loan;  -- wystarczy tabela loan, bo mamy przecież tu account_id i to wystarczy do uszeregowania kont

/*Spłacone pożyczki
Sprawdź saldo pożyczek spłaconych w podziale na płeć klienta.
Dodatkowo w wybrany przez siebie sposób sprawdź, czy kwerenda jest poprawna.*/
SELECT
    c.gender,
    SUM(l.amount) AS saldo
    FROM loan l
INNER JOIN disp d ON l.account_id = d.account_id -- można też USING(account_id)
INNER JOIN client c ON d.client_id = c.client_id
WHERE l.status IN ('A', 'C')
GROUP BY c.gender;

-- sprawdzenie
DROP TABLE IF EXISTS tmp_result;
CREATE TEMPORARY TABLE tmp_result AS(SELECT
    c.gender,
    SUM(l.amount) AS saldo
    FROM loan l
INNER JOIN disp d ON l.account_id = d.account_id
INNER JOIN client c ON d.client_id = c.client_id
WHERE l.status IN ('A', 'C')
GROUP BY c.gender);
-- sprawdzam saldo w moim pytaniu i tylko z loan (z pominięciem tabeli account)
WITH cte AS (
    SELECT SUM(amount) as amount
    FROM loan as l
    WHERE status IN('A', 'C')
)
SELECT (SELECT SUM(saldo) FROM tmp_result) - (SELECT amount from cte); -- nie wyszło zero!;
-- sprawdzam ilość account_id poszczególnych w disp:
SELECT disp.account_id, COUNT(disp.account_id) FROM disp GROUP BY account_id ORDER BY count(account_id) DESC;
SELECT * FROM disp WHERE account_id = 1095; -- 2 różne client ID, jeden OWNER, jeden DISPONENT
-- trzeba dodać warunek o właścicielu konta do kwerendy jednak
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
# Analiza klienta cz. 1
# Modyfikując zapytania z zadania dot. spłaconych pożyczek, odpowiedz na poniższe pytania:
#  - kto posiada więcej spłaconych pożyczek – kobiety czy mężczyźni?
#  - jaki jest średni wiek kredytobiorcy w zależności od płci?
DROP TABLE IF EXISTS tmp_client_analysis;
CREATE TEMPORARY TABLE tmp_client_analysis AS (
SELECT
    c.gender,
    2021 - EXTRACT(YEAR FROM c.birth_date) AS age,
    SUM(l.amount) AS saldo,
    COUNT(l.amount) AS loan_count
    FROM loan l
INNER JOIN disp d ON l.account_id = d.account_id -- można też USING(account_id)
INNER JOIN client c ON d.client_id = c.client_id
WHERE l.status IN ('A', 'C')
AND d.type = 'OWNER'
GROUP BY c.gender, 2);  -- trzeba dodać drugą kolumnę do groupbaja
-- odpowiadanie na pytania
SELECT gender,
       AVG(age),
       SUM(loan_count)
FROM tmp_client_analysis
GROUP BY gender;

SELECT * FROM tmp_client_analysis; -- sprawdzam - 88 rows

/*-- rok urodzenia kredytobiorcy
SELECT EXTRACT(YEAR FROM birth_date) AS birth_year
FROM client;*/
/*-- średni wiek kretytobiorcy
SELECT AVG(2021 - EXTRACT(YEAR FROM c.birth_date)) FROM client c;*/

# Analiza klienta cz. 2
# Dokonaj analiz, które odpowiedzą na pytania:
#  - w którym rejonie jest najwięcej klientów, -- clirnts
#  - w którym rejonie zostało spłaconych najwięcej pożyczek ilościowo, -- loan_count
#  - w którym rejonie zostało spłaconych najwięcej pożyczek kwotowo -- loan_saldo
# Jako klienta wybierz tylko właścicieli kont.
SELECT
    A2 as district_name,
    COUNT(l.account_id) AS clients,
    SUM(l.amount) AS loan_saldo,
    COUNT(l.loan_id) AS loan_count
FROM loan l
INNER JOIN disp d ON l.account_id = d.account_id -- można też USING(account_id)
INNER JOIN client c ON d.client_id = c.client_id
INNER JOIN district ds ON c.district_id = ds.district_id
WHERE l.status IN ('A', 'C')
AND d.type = 'OWNER'
GROUP BY c.district_id
ORDER BY loan_count DESC;  -- 76 rows

# Analiza klienta cz 3
# Używając kwerendy otrzymanej w poprzednim zadaniu, dokonaj jej modyfikacji w taki sposób,
# aby wyznaczyć procentowy udział każdego regionu w całkowitej kwocie udzielonych pożyczek.
# nnymi słowy, chodzi o wyznaczenie rozkładu udzielanych pożyczek ze względu na regiony.
WITH l_stats AS (
SELECT
    A2 as district_name,
    COUNT(l.account_id) AS clients_count,
    SUM(l.amount) AS loan_saldo,
    COUNT(l.loan_id) AS loan_count
FROM loan l
INNER JOIN disp d ON l.account_id = d.account_id -- można też USING(account_id)
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

# Selekcja cz 1
# Sprawdź, czy w bazie występują klienci spełniający poniższe warunki:
#  - saldo konta przekracza 1000,
#  - mają więcej niż pięć pożyczek,
#  - są urodzeni po 1990 r.
# Przy czym zakładamy, że saldo konta to kwota pożyczki - wpłaty
SELECT
    c.client_id,
    SUM(l.amount) AS loan_amount,  -- zmieniam nazmę na amount
    COUNT(l.loan_id) AS loan_count,
    (SUM(l.amount) - SUM(payments)) AS saldo_konta
FROM loan l
INNER JOIN disp d ON l.account_id = d.account_id -- można też USING(account_id)
INNER JOIN client c ON d.client_id = c.client_id
WHERE l.status IN ('A', 'C')
AND d.type = 'OWNER'
AND birth_date > '1990-12-31'
GROUP BY c.client_id
HAVING saldo_konta > 1000 AND loan_count > 5  -- mamy pusty zbiór wynikowy
;
-- próba napisania od nowa
SELECT
    client_id
FROM client c
WHERE birth_date > '1990-12-31';  -- nie ma klientów urodzonych po 1990 roku

SELECT
    c.client_id,
    COUNT(loan_id)
FROM client c
INNER JOIN disp d on c.client_id = d.client_id
INNER JOIN loan l ON d.account_id = l.account_id
WHERE d.type = 'OWNER'
GROUP BY c.client_id
ORDER BY COUNT(loan_id) DESC; -- nie ma klientów z więcej niż jedną pożyczką

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
HAVING (SUM(l.amount) - SUM(payments)) > 1000; -- 606 wierszy
-- w ten sposób można odpowiedzieć na pytania za pomocą prostszych kwerend...

# Selekcja cz. 2
# Z poprzedniego zadania prawdopodobnie już wiesz, że nie ma klientów, którzy spełniali wymagane kryteria.
# Dokonaj analizy, za pomocą której określisz, który warunek spowodował brak wyników.
SELECT
    c.client_id,
    SUM(l.amount) AS loan_amount,  -- zmieniam nazmę na amount
    COUNT(l.loan_id) AS loan_count,
    (SUM(l.amount) - SUM(payments)) AS saldo_konta
FROM loan l
INNER JOIN disp d ON l.account_id = d.account_id -- można też USING(account_id)
INNER JOIN client c ON d.client_id = c.client_id
WHERE l.status IN ('A', 'C')
AND d.type = 'OWNER'
# AND birth_date > '1990-12-31' -- nie ma klientóww urodzonych po 1990 roku
GROUP BY c.client_id
HAVING saldo_konta > 1000
#    AND loan_count > 5 -- nie ma klientów mających więcej niż 1 pożyczkę
ORDER BY loan_count DESC; -- 606 wierszy

# Wygasające karty
# Napisz procedurę, która będzie odświeżać stworzoną przez Ciebie tabelę (możesz nazwać ją np. cards_at_expiration)
# zawierającą następujące kolumny:
#  - id klienta,
#  - id_karty,
# data wygaśnięcia – załóż, że karta może być aktywna przez 3 lata od wydania,
# adres klienta (wystarczy kolumna A3).
# Uwaga: W tabeli card zawarte są karty, które zostały wydane do końca 1998.
-- najpierw zapytanie
SELECT cl.client_id,
       c.card_id,
       ADDDATE(c.issued, INTERVAL 3 YEAR ) AS expiration_date,
       dst.A3 AS client_region
FROM client cl
INNER JOIN district dst ON cl.district_id = dst.district_id
INNER JOIN disp d ON cl.client_id = d.client_id
INNER JOIN card c ON d.disp_id = c.disp_id;
-- trzeba stworzyć tabelę: - nie możemy tworzyć tabeli w bazie, więc robię tmp
CREATE TEMPORARY TABLE tmp_cards_at_expiration
(
    client_id       int                      not null,
    card_id         int default 0            not null,
    expiration_date date                     null,
    A3              varchar(15) charset utf8 not null,
    generated_for_date date                     null
);
-- wg rozwiązania należy dodać do kwerenty zapytania wyszukujące karty, które kończą się za 7 dni od podanej daty
WITH card_stats AS(
    SELECT cl.client_id,
       c.card_id,
       ADDDATE(c.issued, INTERVAL 3 YEAR ) AS expiration_date,
       dst.A3 AS client_region
       -- tu dodać jeszcze na kiedy generowane
FROM client cl
INNER JOIN district dst ON cl.district_id = dst.district_id
INNER JOIN disp d ON cl.client_id = d.client_id
INNER JOIN card c ON d.disp_id = c.disp_id
)
SELECT * FROM card_stats
WHERE expiration_date BETWEEN ADDDATE(input_date, INTERVAL -7 DAY) AND input_date;

-- tworzymy procedurę
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

