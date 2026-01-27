-- Do not run now, just conceptual
CREATE OR REPLACE TABLE `my_project.my_dataset.stg_posts_questions_partitioned`
PARTITION BY DATE(creation_date)
AS
SELECT * FROM `bigquery-public-data.stackoverflow.posts_questions`
WHERE creation_date >= '2010-01-01';