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
      - I honestly couldn't come up with a great way to reliably test this.
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
      - Only one result present: 'ls2 large'
