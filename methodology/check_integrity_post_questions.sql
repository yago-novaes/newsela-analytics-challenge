select 
  table_name, 
  column_name, 
  data_type
from 
  bigquery-public-data.stackoverflow.INFORMATION_SCHEMA.COLUMNS
where 
  table_name = 'posts_questions'
  and is_partitioning_column = 'YES';

select 
    id, 
    count(*) as counts
from bigquery-public-data.stackoverflow.posts_questions
group by 1 
having counts > 1;

select 
    id 
from bigquery-public-data.stackoverflow.posts_questions
where id is null;

select 
    count(id) as questions_count
from 
    `bigquery-public-data.stackoverflow.posts_questions`
where 
    tags like '|%' 
    or tags like '%|';