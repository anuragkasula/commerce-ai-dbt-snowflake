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

-- If a function errors with a model/region message (not a trial message), as ACCOUNTADMIN:
--   alter account set cortex_enabled_cross_region = 'ANY_REGION';
-- Governance note: that is a DATA RESIDENCY decision, not just a switch.
