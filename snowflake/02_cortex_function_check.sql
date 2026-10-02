-- =====================================================================
-- 02_cortex_function_check.sql  |  Which Cortex functions does THIS account allow?
-- Trial accounts restrict some AI functions (AI_SENTIMENT is blocked on trial).
-- Run each statement ON ITS OWN (select it, then Ctrl/Cmd+Enter) so one
-- failure doesn't hide the others. Note which ones work.
-- =====================================================================
use role transformer;
use warehouse commerce_wh;

-- A. AI_CLASSIFY: fixed categories. Returns an OBJECT like {"labels": ["shipping delay"]}
select ai_classify('My shipment is three weeks late and nobody replies',
                   ['shipping delay', 'billing', 'product defect']) as result;

-- B. AI_EXTRACT: named fields out of free text. Returns an OBJECT with a "response" key.
select ai_extract('Order ORD-10479 for the EdgeSwitch 24 arrived with a damaged power supply',
                  {'order_id': 'What is the order id?', 'product': 'What product is mentioned?'}) as result;

-- C. AI_COMPLETE: general LLM call. Try the first model; if it errors, try the next.
select ai_complete('llama3.1-8b', 'In five words, what is a data warehouse?') as result;
select ai_complete('mistral-large2', 'In five words, what is a data warehouse?') as result;
select ai_complete('claude-3-5-sonnet', 'In five words, what is a data warehouse?') as result;

-- D. AI_FILTER: yes/no question -> BOOLEAN. Usable directly in a WHERE clause.
select ai_filter('Is this customer threatening to cancel? Text: Fix this by Friday or we cancel the remaining order.') as result;

-- E. AI_TRANSLATE: (text, source_language, target_language); '' = auto-detect source
select ai_translate('El pedido no ha llegado y el cliente esta muy molesto', '', 'en') as result;

-- F. AI_SENTIMENT (expected to FAIL on trial) and the older CORTEX.SENTIMENT fallback
select ai_sentiment('My shipment is three weeks late and nobody replies') as result;
select snowflake.cortex.sentiment('My shipment is three weeks late and nobody replies') as result;  -- float -1..1

-- G. AI_AGG: aggregate across ROWS with an instruction
select ai_agg(note, 'Summarize the main complaint themes in one sentence') as result
from (select column1 as note from values
      ('Shipment late again'), ('Invoice charged twice'), ('Delivery slipped a third time'));

-- H. AI_SUMMARIZE_AGG: summarize across rows, no instruction needed
select ai_summarize_agg(note) as result
from (select column1 as note from values
      ('Shipment late again'), ('Invoice charged twice'), ('Delivery slipped a third time'));

-- =====================================================================
-- RESULT ON THIS TRIAL ACCOUNT (2026-10-02): A-F and every SNOWFLAKE.CORTEX.*
-- per-row function return "not available for trial accounts". Only the
-- aggregate functions G (AI_AGG) and H (AI_SUMMARIZE_AGG) work.
--
-- WORKAROUND: GROUP BY a unique key so each group holds ONE row; AI_AGG then
-- applies the instruction to that single row, acting like a per-row LLM call.
-- Output is free text, so the dbt models validate it (TRY_PARSE_JSON,
-- accepted_values) instead of trusting it. Production code would use
-- AI_CLASSIFY / AI_EXTRACT, which return structured output and cost less.
-- =====================================================================
select case_id,
       ai_agg(note, 'Classify this support note into exactly one of: shipping delay, pricing or billing, licensing, product defect, installation help. Reply with the label only, lowercase, no punctuation.') as issue_type,
       ai_agg(note, 'Return only JSON with keys order_id and product. Use null if not mentioned. No other text.') as extracted
from (select column1 as case_id, column2 as note from values
      ('CASE-1', 'Order ORD-10479 for the EdgeSwitch 24 is three weeks late and tracking has not updated'),
      ('CASE-2', 'Customer was invoiced twice for the ShieldWall 200 and wants a refund'),
      ('CASE-3', 'El pedido ORD-10233 llego con la fuente de alimentacion danada'))
group by case_id;

-- If a function errors with a model/region message (not a trial message), as ACCOUNTADMIN:
--   alter account set cortex_enabled_cross_region = 'ANY_REGION';
-- Governance note: that is a DATA RESIDENCY decision, not just a switch.
