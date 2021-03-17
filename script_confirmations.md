### Scripts used to confirm query validity

4)
  - post_code
      - SELECT COUNT(post_code) FROM street_cafe_by_post;
      - SELECT COUNT(DISTINCT post_code) FROM street_cafes;
      - Inspected for equality

  - total_places
      - SELECT COUNT(street_address), total_places, street_cafes.post_code, (COUNT(street_address) = total_places) AS test_result FROM street_cafes
        INNER JOIN (
          SELECT total_places, street_cafe_by_post.post_code FROM street_cafe_by_post
        ) AS aggs ON street_cafes.post_code = aggs.post_code
        GROUP BY street_cafes.post_code, aggs.total_places;
      - Ensured no false values present in test_result column

  - chairs_pct
      - SELECT SUM(chairs_pct) FROM street_cafe_by_post;
          - Is it 100%?
      - SELECT SUM(number_of_chairs) FROM street_cafes;
      - SELECT (SUM(number_of_chairs)::float / 2079 * 100 ) AS test_pct, chair_pct,
        (SUM(number_of_chairs)::float / 2079 * 100 = chair_pct) AS test_result FROM street_cafes
        INNER JOIN (
          SELECT post_code, chair_pct FROM street_cafe_by_post
          ) AS aggs ON street_cafes.post_code = aggs.post_code
        GROUP BY street_cafes.post_code, aggs.chair_pct;
      - Ensured no false values in test_result column

  - place_with_max_chairs
      - I honestly couldn't come up with a great way to reliably check this.
      - SELECT name, number_of_chairs, post_code FROM street_cafes ORDER BY post_code;
      - SELECT place_with_max_chairs, max_chairs, post_code FROM street_cafe_by_post;
      - No pun, spot checked.

5) After running script
  - ls1 small
      - SELECT DISTINCT category FROM street_cafes
        WHERE number_of_chairs < 10 AND post_code LIKE 'LS1 %';
      - Only one result present: 'ls1 small'
  - ls1 medium
      - SELECT DISTINCT category FROM street_cafes
        WHERE number_of_chairs >= 10 AND number_of_chairs < 100 AND post_code LIKE 'LS1 %';
      - Only one result present: 'ls1 medium'
  - ls1 large
      - SELECT DISTINCT category FROM street_cafes
        WHERE number_of_chairs >= 100 AND post_code LIKE 'LS1 %';
      - Only one result present: 'ls1 large'
  - ls2 small
      - With 50th percentile calculated to be 35.5
      - SELECT DISTINCT category FROM street_cafes
        WHERE number_of_chairs < 35.5 AND post_code LIKE 'LS2 %';
      - Only one result present: 'ls2 small'
  - ls2 large
      - With 50th percentile calculated to be 35.5
      - SELECT DISTINCT category FROM street_cafes
        WHERE number_of_chairs > 35.5 AND post_code LIKE 'LS2 %';
      - Only one result present: 'ls2 large'
  - other
      - SELECT DISTINCT category FROM street_cafes
        WHERE post_code NOT LIKE 'LS2 %' AND post_code NOT LIKE 'LS1 %';
      - Only one result present: 'other'
  - For all the above:
      - SELECT post_code, category, number_of_chairs FROM street_cafes
        ORDER BY category;
      - Sanity checked

6) After creating view
  - SELECT SUM(number_of_chairs) AS test_total_chairs, COUNT(street_address) as test_place_count FROM street_cafes WHERE category LIKE 'ls1 small';
  - SELECT * FROM category_aggregates;
  - Iterate on first query for each category and compare to values in view to ensure parity

7)
  - CSV export and deletion from table of small cafes
      - CREATE TABLE copied_small_cafes (
        name VARCHAR ( 50 ) NOT NULL,
        street_address VARCHAR ( 50 ) NOT NULL,
        post_code VARCHAR ( 10 ) NOT NULL,
        number_of_chairs SMALLINT  NOT NULL),
        category VARCHAR ( 10 )  NOT NULL);
      - run script
      - COPY copied_small_cafes(name, street_address, post_code, number_of_chairs, category)
        FROM 'path/to/output/file'
        DELIMITER ','
        CSV HEADER;
      - reset database(StreetCafeScripts.new(scripts_db).reset_street_cafes)
      - CREATE VIEW original_small_cafes AS (
        SELECT * FROM street_cafes WHERE category LIKE '% small'
        )
      - (TABLE copied_small_cafes EXCEPT TABLE original_small_cafes)
        UNION ALL
        (TABLE original_small_cafes EXCEPT TABLE copied_small_cafes);
      - Confirmed empty result of above hopefully validating that the exports
      - run script again
      - Confirm with above query that entirey of copied_small_cafes is absent from street_cafes
  - Renaming of medium/large cafes
      - SELECT name, category, (name LIKE CONCAT(category, '%')) as test_result FROM street_cafes
        WHERE( category LIKE '%medium' OR category LIKE '%large');
      - Ensure no false values in test result column

