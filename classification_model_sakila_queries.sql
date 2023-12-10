use sakila;
/*

Potentially applicable information from sakila db for predicting which films will be rented
- Popular actors in movies - added boolean if actor in more than average actor appearance in db is in movie
- Most popular categories - nominal category
- Most popular films by ratings - nominal category
- Most popular films by release year - all release year is 2006
- 
consider: more popular than the average

*/

-- Determining if a actor is popular or not based on number of movie appearances from database
DROP VIEW IF EXISTS sakila.actor_popularity_view;

CREATE VIEW sakila.actor_popularity_view AS (
SELECT actor_id, COUNT(film_id) as num_appearances,
AVG(COUNT(film_id)) OVER (PARTITION BY COUNT(DISTINCT(actor_id))) AS average_threshold,
CASE WHEN COUNT(film_id) > (AVG(COUNT(film_id)) OVER (PARTITION BY COUNT(DISTINCT(actor_id)))) THEN 'popular'
ElSE 'not popular'
END AS popularity_status
FROM sakila.film_actor
GROUP BY actor_id
);

SELECT *
FROM actor_popularity_view;


-- Temporary table for determining the number of popular actors in a movie.
DROP VIEW IF EXISTS sakila.total_popular_actors_in_movie;

CREATE VIEW sakila.total_popular_actors_in_movie AS (
SELECT 
	fa.film_id, 
    COUNT(apv.actor_id) as num_popular_actors
FROM sakila.film_actor fa
LEFT JOIN sakila.actor_popularity_view apv
ON apv.actor_id = fa.actor_id
WHERE apv.popularity_status = 'popular' 
GROUP BY fa.film_id
ORDER BY fa.film_id ASC
);

SELECT *
FROM sakila.total_popular_actors_in_movie;


-- Temporary table for films with popular actors

DROP VIEW IF EXISTS sakila.films_with_popular_actors;

CREATE VIEW sakila.films_with_popular_actors AS (
SELECT 
	DISTINCT(fa.film_id)
FROM sakila.actor_popularity_view apv
LEFT JOIN sakila.film_actor fa
ON apv.actor_id = fa.actor_id
WHERE apv.popularity_status = 'popular'
ORDER BY fa.film_id ASC
);

SELECT *
FROM sakila.films_with_popular_actors;

-- View for total rentals per film title
DROP VIEW IF EXISTS total_rentals_per_film;

CREATE VIEW total_rentals_per_film AS (
SELECT COUNT(r.rental_id) as total_rentals, f.title
FROM sakila.rental r
JOIN sakila.inventory i
ON r.inventory_id = i.inventory_id
JOIN sakila.film f
ON i.film_id = f.film_id
GROUP BY f.title
);

SELECT *
FROM total_rentals_per_film;

-- View for movie titles rented in May 2005
DROP VIEW IF EXISTS may_05_movies;

CREATE VIEW may_05_movies AS (
SELECT DISTINCT(f.title)
FROM sakila.rental r
JOIN sakila.inventory i 
ON r.inventory_id = i.inventory_id
JOIN sakila.film f
ON i.film_id = f.film_id
WHERE MONTH(r.rental_date) = 5
AND YEAR(r.rental_date) = 2005
);

SELECT * FROM may_05_movies;

-- Main query for unique film titles with rented_in_may column with additional X columns

SELECT 
	DISTINCT(f.title), 
	f.rating, 
    f.length,
    f.film_id, 
    c.name as category_name, 
    IFNULL(tr.total_rentals, 0) as total_rentals,
	CASE
		WHEN f.film_id IN(fp.film_id) THEN 'True'
		ELSE 'False'
	END AS includes_popular_actor,
	CASE
		WHEN f.film_id IN(tpma.film_id) THEN tpma.num_popular_actors
        ELSE 0
	END AS 'total_popular_actors_in_movie',
    CASE
		WHEN f.title IN(m.title) THEN 'True'
		ELSE 'False'
	END AS rented_in_may
FROM sakila.film f
LEFT JOIN sakila.inventory i
ON f.film_id = i.film_id
LEFT JOIN sakila.rental r
ON i.inventory_id = r.inventory_id
LEFT JOIN sakila.films_with_popular_actors fp
ON f.film_id = fp.film_id
LEFT JOIN sakila.film_category fc
ON f.film_id = fc.film_id
LEFT JOIN sakila.category c
ON fc.category_id = c.category_id
LEFT JOIN total_popular_actors_in_movie tpma
ON f.film_id = tpma.film_id
LEFT JOIN total_rentals_per_film tr
ON f.title = tr.title
LEFT JOIN may_05_movies m
ON f.title = m.title
ORDER BY rented_in_may DESC, f.title ASC;