-- Query 1:

--Finding duplicates in a table.

--DROP TABLE users;
CREATE TABLE users
(
user_id INT PRIMARY KEY,
user_name VARCHAR(30) not null,
email VARCHAR(50));

INSERT INTO users VALUES
(1, 'Jimrey', 'Jimrey@gmail.com'),
(2, 'Nathalia', 'Nathalia@gmail.com'),
(3, 'Stephanie', 'Stephanie@gmail.com'),
(4, 'Lance', 'Lance@gmail.com'),
(5, 'James', 'James@gmail.com'),
(6, 'Theodora', 'Theodora@gmail.com'),
(7, 'Theodora', 'Theodora@gmail.com');

SELECT * FROM users;

--WINDOW FUNCTION METHOD
SELECT user_id, user_name, email
FROM (
SELECT *,
row_number() OVER (PARTITION BY user_name ORDER BY user_id) AS rn
FROM users u) a
WHERE a.rn <> 1;

--EXITS with a SUB_QUERY METHOD
SELECT *
FROM users AS t1
WHERE EXISTS (
    SELECT 1
    FROM users AS t2
    WHERE t1.user_name = t2.user_name
    AND t1.user_id <> t2.user_id -- Exclude the current row itself
);

