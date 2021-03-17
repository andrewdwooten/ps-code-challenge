require 'pg'

class StreetCafeScripts
  attr_reader :conn
  def initialize(db_name)
    @conn = PG.connect dbname: db_name
    @data_file_path = File.expand_path("Street Cafes 2020-21.csv")
  end

  def setup_street_cafes
    create_street_cafes_table
    add_category_to_street_cafes
    load_street_cafes_data
    categorize_street_cafes
  end

  def reset_street_cafes
    conn.exec("DROP TABLE street_cafes CASCADE;")
    setup_street_cafes
  end

  def create_street_cafes_table
    conn.exec "CREATE TABLE street_cafes (
                name VARCHAR ( 50 ) NOT NULL,
                street_address VARCHAR ( 50 ) NOT NULL,
                post_code VARCHAR ( 10 ) NOT NULL,
                number_of_chairs SMALLINT  NOT NULL);"
  end

  def add_category_to_street_cafes
    conn.exec "ALTER TABLE street_cafes
                ADD COLUMN category VARCHAR;"
  end

  def load_street_cafes_data
    conn.exec "COPY street_cafes(name, street_address, post_code, number_of_chairs, category)
              FROM '#{@data_file_path}'
              DELIMITER ','
              CSV HEADER;"
  end

  def create_post_code_grouped_view
    conn.exec (
      "CREATE VIEW street_cafe_by_post AS WITH total_chair_count AS (
        SELECT SUM(number_of_chairs) AS count FROM street_cafes )
        SELECT name AS place_with_max_chairs, a.post_code,  a.number_of_chairs AS max_chairs,
          b.total_chairs, b.total_places,
          b.total_chairs::float / (SELECT total_chair_count.count FROM total_chair_count) * 100 chair_pct
        FROM street_cafes a
        INNER JOIN (
          SELECT post_code, MAX(number_of_chairs) number_of_chairs, SUM(number_of_chairs) total_chairs, COUNT(*) total_places
          FROM street_cafes b
          GROUP BY post_code
        ) b ON a.post_code = b.post_code AND a.number_of_chairs = b.number_of_chairs;"
      )
  end

  def categorize_street_cafes
    conn.exec (
      "UPDATE street_cafes
      SET category = case
      WHEN number_of_chairs < 10 THEN 'ls1 small'
      WHEN (number_of_chairs >= 10 AND number_of_chairs < 100) THEN 'ls1 medium'
      WHEN number_of_chairs >= 100 THEN 'ls1 large'
      END
      WHERE post_code LIKE 'LS1 %';"
      )

    conn.exec (
      "WITH percentile AS (
      SELECT PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY number_of_chairs)
      FROM street_cafes
      WHERE post_code LIKE 'LS2%')
      UPDATE  street_cafes
      SET
        category = case
      WHEN number_of_chairs  < (SELECT percentile.percentile_cont FROM percentile) THEN 'ls2 small'
      WHEN number_of_chairs  > (SELECT percentile.percentile_cont FROM percentile) THEN 'ls2 large'
      END
      WHERE post_code LIKE 'LS2 %'
      ;"
    )

    conn.exec (
      "UPDATE street_cafes
      SET category = 'other'
      WHERE post_code NOT LIKE 'LS1 %' AND post_code NOT LIKE 'LS2 %';"
    )
  end

  def create_category_aggregates_view
    conn.exec (
      "CREATE VIEW category_aggregates AS (
      SELECT category, COUNT(street_address) as total_places, SUM(number_of_chairs) AS total_chairs FROM street_cafes
      GROUP BY category);"
      )
  end

  def export_small_cafes_to_csv_and_delete
      File.new("output.csv", "w")
      File.open("output.csv", 'w') do |f|
        conn.copy_data "COPY (SELECT  * FROM street_cafes WHERE category = 'ls1 small' OR category = 'ls2 small') TO STDOUT WITH (FORMAT CSV, HEADER TRUE)" do
          while row=conn.get_copy_data
            f.write row
          end
        end
      end

      conn.exec (
        "DELETE FROM street_cafes
         WHERE category = 'ls1 small' OR category = 'ls2 small'
         ;"
      )
  end

  def update_medium_and_large_street_cafes_names
    conn.exec(
      "UPDATE street_cafes
      SET name = category || '-' || name
      WHERE category LIKE '%medium' OR category LIKE '%large'
      ;"
    )
  end
end
StreetCafeScripts.new('scripts_db').reset_street_cafes
