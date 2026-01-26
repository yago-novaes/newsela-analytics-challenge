select
    table_name,
    column_name,
    data_type,
    is_nullableublic
from `bigquery-p-data.stackoverflow.INFORMATION_SCHEMA.COLUMNS`
where table_name in (
    'badges',
    'comments',
    'post_history',
    'post_links',
    'posts_answers',
    'posts_moderator_nomination',
    'posts_orphaned_tag_wiki',
    'posts_privilege_wiki',
    'posts_questions',
    'posts_tag_wiki',
    'posts_tag_wiki_excerpt',
    'posts_wiki_placeholder',
    'stackoverflow_posts',
    'tags',
    'users',
    'votes'
)
order by table_name, ordinal_position;