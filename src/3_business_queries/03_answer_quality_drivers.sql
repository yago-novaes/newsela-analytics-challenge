-- 3. other than tags, what qualities on a post correlate with the highest rate of answer and approved answer? 
-- feel free to get creative 

-- to answer this question, i tried to think as a stack overflow user
-- another thing i thought about is "what prevents me from answering forms, questionnaires, etc?"
-- 1. if the form or question is too long (body length)
-- 2. if the question is unclear
-- 3. if the answer would take too long to write (laziness factor) -- maybe i can check on posts_answers
-- 4. if a question is too difficult or specific (harder to validate via sql)
-- 5. if i didn't see it or wasn't alerted (visibility/timing: weekday vs weekend).
-- 6. if the question is a wall of text without code blocks (formatting/readability)
-- 7. the title isn't flashy, sounds desperate (contains 'urgent', 'help', 'asap')

-- architectural decisions:
-- i tried to group synonymous hypotheses into the same bucket.
-- i don't have time for detailed studies on all these points, and sql isn't the best tool for this type of deep behavioral analysis
-- i opted to query only the `posts_questions` table instead of joining with `posts_answers`
-- joining with answers would cause row fan-out (1 question -> n answers), requiring complex re-aggregation and inflating costs without adding value to the analysis of the question's structural quality
-- [discarded] if a question is too difficult or specific -- difficulty is subjective and requires nlp/complex text analysis, which is out of scope for a pure sql approach.


-- pool 1: cognitive load & readability (effort friction) - 1, 2, 3, 6 and 7
-- pool 2: availability (visibility/timing) - 5


with posts_questions as (

    select 
       id,
       answer_count,
       accepted_answer_id,
       title,
       body,
       creation_date
    from 
        `bigquery-public-data.stackoverflow.posts_questions`
    where 
        creation_date between '2022-01-01' and '2022-12-31'

)

, features_extraction as (

    select 
        id,
        answer_count,
        accepted_answer_id,
        
        -- pool 1: structural quality flags (independent factors)
        -- these allow us to measure interaction effects (e.g., short title AND no code)
        
        -- unclear/short title - 35 derived from P10 distribution analysis
        char_length(title) < 35 as is_short_title,
        
        -- desperate/unprofessional title
        regexp_contains(lower(title), r'urgent|help|asap|!!!') = false as is_desperate_title,
        
        -- wall of text (readability)
        case when body not like '%<code>%' then true else false end as has_no_code_block,
        
        -- length friction - 5300 P95 distribution analysis
        char_length(body) > 5300 as is_too_long,
        
        -- vague content
        char_length(body) < 200 as is_too_short,

        -- pool 2
        -- hypothesis 5
        case 
            when extract(dayofweek from creation_date) in (1, 7) then 'weekend'
            else 'weekday'
        end as day_type
    from
      posts_questions

),

metrics_consolidation as (

    select
        is_short_title,
        is_desperate_title,
        has_no_code_block,
        is_too_long,
        is_too_short,
        day_type,
        count(id) as total_questions,
        avg(answer_count) as avg_answers, -- engagement volume
        sum(answer_count) as total_answers,
        count(accepted_answer_id) / count(id) as approved_rate
    from 
        features_extraction
    group by 
        is_short_title,
        is_desperate_title,
        has_no_code_block,
        is_too_long,
        is_too_short,
        day_type

)

, final_metrics as (

    select 
        is_short_title,
        is_desperate_title,
        has_no_code_block,
        is_too_long,
        is_too_short,
        day_type,
        total_questions,
        round(avg_answers, 2) as avg_answers,
        round(approved_rate * 100, 2) as approved_rate_pct
    from 
        metrics_consolidation
    order by 
        approved_rate_pct desc

)

select * from final_metrics ;