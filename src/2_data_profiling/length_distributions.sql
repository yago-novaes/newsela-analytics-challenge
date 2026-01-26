
-- Data Profiling: Title and Body Length Distribution
-- Objective: Determine statistical thresholds for "Short Title" and "Long Body"


select
  -- Title Analysis
  min(char_length(title)) as min_title,
  approx_quantiles(char_length(title), 100)[offset(10)] as p10_title_threshold, -- 10% of titles are shorter than this
  avg(char_length(title)) as avg_title,
  
  -- Body Analysis
  min(char_length(body)) as min_body,
  avg(char_length(body)) as avg_body,
  approx_quantiles(char_length(body), 100)[offset(90)] as p90_body_threshold, -- 90% of bodies are shorter than this (P90)
  approx_quantiles(char_length(body), 100)[offset(95)] as p95_body_threshold, -- Extreme outliers
  max(char_length(body)) as max_body
from
  `bigquery-public-data.stackoverflow.posts_questions`
where
  creation_date between '2022-01-01' and '2022-12-31';