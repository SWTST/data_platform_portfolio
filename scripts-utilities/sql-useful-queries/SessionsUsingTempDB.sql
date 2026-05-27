-- Check which sessions are using the most tempDB

sp_who2
SELECT 
    session_id, 
    SUM(internal_objects_alloc_page_count + user_objects_alloc_page_count) * 8 AS total_kb_used
FROM sys.dm_db_session_space_usage
GROUP BY session_id
ORDER BY total_kb_used DESC;