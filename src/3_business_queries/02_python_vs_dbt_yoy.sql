--2. For posts which are tagged with only ‘python’ or ‘dbt’, what is the year over year change of question-to-answer ratio for the last 10 years? 
--How about the rate of approved answers on questions for the same time period? 
--How do posts tagged with only ‘python’ compare to posts only tagged with ‘dbt’?

-- same thing that dbt variables, this could be apllied when we want a dynamic filter without scan a dataset column
declare target_end_year int64 default extract(year from current_date());
declare target_start_year int64 default extract(year from current_date()) - 10; 


with post_questions as (

    --filtering early to reduce dataset size immediately
    select 
        creation_date,
        tags,
        id,
        answer_count,
        accepted_answer_id
    from 
        `bigquery-public-data.stackoverflow.posts_questions`
    where 
        creation_date between '2012-01-01' and '2022-12-31'
        and tags in ('python', 'dbt')

)

, yearly_metrics as (

    -- grouping data by year and tag to prepare for metric calculation
    -- no need to repeat the 'where' clause here since the input cte is already filtered
    select 
        extract(year from creation_date) as post_year,
        tags as tag,
        count(id) as total_questions,
        sum(answer_count) as total_answers,
        countif(accepted_answer_id is not null) as total_accepted
    from 
        post_questions
    group by 
        post_year, -- best practice in production
        tag
    
),

calculated_ratios as (

    --metric calculation
    select
        post_year,
        tag,
        total_questions,
        -- simple division is safe here because rows with total_questions=0 won't exist in the aggregation result
        total_answers / total_questions as q_to_a_ratio, -- question-to-answer ratio
        total_accepted / total_questions as approved_rate -- rate of approved answers
    from 
        yearly_metrics

)


, final_metrics as (
    
    -- window functions fro yoy and formatting
    select
        post_year,
        tag,
        total_questions,
        round(q_to_a_ratio, 2) as q_to_a_ratio,
        round(approved_rate * 100, 2) as approved_rate_pct,
        
        -- window function to compare current year vs previous year (lag)
        -- i dont force 0 to first year because 0% growth != undefined growth
        round((q_to_a_ratio - lag(q_to_a_ratio) over (partition by tag order by post_year)) 
            / nullif(lag(q_to_a_ratio) over (partition by tag order by post_year), 0) * 100, 2) as ratio_yoy_growth_pct
    from 
        calculated_ratios
    order by 
        post_year desc, tag
        
)

select * from final_metrics; 