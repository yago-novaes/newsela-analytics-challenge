-- 1. What tags on a Stack Overflow question lead to the most answers and the highest rate of approved answers for the current year?
-- What tags lead to the least? 
-- How about combinations of tags?

declare target_year int64 default extract(year from current_date());

-- the dataset is outdated, therefore the last treatment year is 2022, but otherwise i would use the solution below declaring from current_date(), which is much more optimized and cheaper than extracting some column within the dataset
-- if was dbt we could create variables like this (next_month, last_quarter, etc.) and use them in our models

with post_questions as (
  -- filtering only the necessary data
  select 
    id,
    tags,
    answer_count,
    accepted_answer_id
  from 
    `bigquery-public-data.stackoverflow.posts_questions`
  where
    --preferred 'between' over 'extract(year)' to enforce partition pruning
    -- even if the table is not partitioned, this enables 'block pruning' if the table is clustered by date
    creation_date between '2022-01-01' and '2022-12-31'

)

, flat_tag as (
  -- unnest transformation (for cases with more than 1 tag per question)
  -- i opted for unnesting the tags that are combined and transform into an individual tag (the question didn't mention tagged only with one tag)
  select 
    id,
    tag,
    answer_count,
    accepted_answer_id
  from post_questions,
    unnest(split(tags, '|')) as tag

)

, individual_tag as (
  -- metrics/aggregations
  -- in this case i will consider that if a question had more than a tag, the metrics for this question will be counted in each one.
  select
    tag,
    count(id) as total_questions,
    sum(answer_count) as total_answers,
    (count(accepted_answer_id) / count(id)) * 100 as approved_rate
  from flat_tag
  group by tag
  having total_questions > 1000 -- relevance
 
)

, combined_tags as (
  -- in this case i will consider only the questions that have more than one tag, and check the most answered
  -- for this part i couldn't use the flat_tag cte, even if exists the field tags, because this will multiply the metric results based on unnest lines.
  select
    -- Refactor: Normalized tag order to treat 'python|pandas' and 'pandas|python' as the same entity.
    -- Logic: Split string into array -> Unnest -> Sort Alphabetically -> Rejoin string
    (select string_agg(t, '|' order by t) from unnest(split(tags, '|')) t) as tag,
    count(id) as total_questions,
    sum(answer_count) as total_answers,
    (count(accepted_answer_id) / count(id)) * 100 as approved_rate
  from post_questions
  where tags like '%|%'
  group by tag
  having total_questions > 1000

)

-- self-service
--select * from combined_tags -- individual or combined
--order by approved_rate desc -- answers or approved in lead or last 
--limit 10

,final_report as (
-- final report: consolidating all perspectives into a single dataset using union all

-- 1. individual tags: most answers
(
  select 
    '1. individual - most answers' as category,
    tag,
    total_questions,
    total_answers,
    approved_rate
  from individual_tag
  order by total_answers desc
  limit 5
)

union all

(
-- 2. individual tags: highest approved rate 
  select 
    '2. individual - highest approval' as category,
    tag,
    total_questions,
    total_answers,
    approved_rate
  from individual_tag
  order by approved_rate desc
  limit 5
)

union all

-- 3. individual tags: least approved rate
(
  select 
    '3. individual - least approval' as category,
    tag,
    total_questions,
    total_answers,
    approved_rate
  from individual_tag
  order by approved_rate asc
  limit 5
)

union all

-- 4. tag combinations: highest approval
(
  select 
    '4. combinations - highest approval' as category,
    tag,
    total_questions,
    total_answers,
    approved_rate
  from combined_tags
  order by approved_rate desc
  limit 5
)

union all

-- 5. tag combinations: least approval
(
  select 
    '5. combinations - least approval' as category,
    tag,
    total_questions,
    total_answers,
    approved_rate
  from combined_tags
  order by approved_rate asc
  limit 5
)

union all

-- 6. tag combinations: most answers
(
  select 
    '6. combinations - most answers' as category,
    tag,
    total_questions,
    total_answers,
    approved_rate
  from combined_tags
  order by total_answers desc
  limit 5
)

union all

-- 7. tag combinations: least answers
(
  select 
    '7. combinations - least answers' as category,
    tag,
    total_questions,
    total_answers,
    approved_rate
  from combined_tags
  order by total_answers asc
  limit 5
)

) 

select * from final_report;