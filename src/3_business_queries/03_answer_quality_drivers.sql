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

-- architetural decisions:
-- i tried to group synonymous hypotheses into the same bucket.
-- i don't have time for detailed studies on all these points, and sql isn't the best tool for this type of deep behavioral analysis
-- i opted to query only the `posts_questions` table instead of joining with `posts_answers`
-- joining with answers would cause row fan-out (1 question -> n answers), requiring complex re-aggregation and inflating costs without adding value to the analysis of the question's structural quality
--[discarded] if a question is too difficult or specific -- difficulty is subjective and requires nlp/complex text analysis, which is out of scope for a pure sql approach.


-- pool 1: cognitive load & readability (effort friction) - 1, 2, 3, 6 and 7
-- pool 2: availability (visibility/timing) - 5

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
        
        -- pool 1
        case 
            -- unclear/short title
            when char_length(title) < 15 then '1. bad title (too short)'
            
            -- desperate/unprofessional title
            when regexp_contains(lower(title), r'urgent|help|asap|!!!') then '2. desperate title (unprofessional)'
            
            -- wall of text (readability)
            when body not like '%<code>%' then '3. no code formatting (wall of text)' 
            
            -- length friction
            when char_length(body) > 5000 then '4. too long (tl;dr)'
            when char_length(body) < 200 then '5. too short (vague)'
            
            else '6. balanced (sweet spot)'
        end as cognitive_load_bucket,

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
        cognitive_load_bucket,
        day_type,
        count(id) as total_questions,
        avg(answer_count) as avg_answers, -- engagement volume
        sum(answer_count) as total_answers,
        count(accepted_answer_id) / count(id) as approved_rate
    from 
        features_extraction
    group by 
        cognitive_load_bucket,
        day_type

)

, final_metrics as (

    select 
        cognitive_load_bucket,
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