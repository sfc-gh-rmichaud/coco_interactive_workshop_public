-- ============================================================
-- Lab 33 -- Evaluate a Cortex Agent, then make it measurably better
--
-- Creates COCO_WS_LAB33_DB_<you>.LAB with everything an evaluation
-- needs, and -- unlike lab 32 -- it creates the agent for you. That is
-- deliberate: this lab is about measuring an agent, so it has to start
-- from an agent that already exists and is already subtly wrong.
--
-- What setup creates:
--   POLICY_DOCS + POLICY_SEARCH   the prose. SLA targets live ONLY here.
--   SUPPORT_TICKETS               resolution times, no notion of a target.
--   TICKETS_SV                    a semantic view, so the agent has an
--                                 Analyst tool to reach the numbers with.
--   SUPPORT_AGENT_V1              the agent under test, deliberately weak.
--   AGENT_EVAL_INPUTS             six queries with ground truth.
--   EVAL_CONFIG stage             where the evaluation YAML goes.
--
-- The trap this lab is built around:
--
--   SUPPORT_AGENT_V1's instructions never say which tool answers which
--   kind of question, and its Analyst tool is described as though it
--   covers "SLA compliance", which the ticket data cannot support
--   because it holds no targets.
--
--   Measured on a real evaluation run, the result is NOT a wrong
--   answer -- answer_correctness came back 1.0 across all six inputs.
--   The agent compensates for the missing guidance by reaching for
--   every tool it has: on the purely numeric question it called the
--   document search as well as the Analyst tool, scoring 0.5 on tool
--   selection accuracy, which penalises an unnecessary call exactly as
--   hard as a missing one.
--
--   That is the lesson, and it is a better one than a wrong answer
--   would have been: an agent can be completely right and still be
--   working badly, paying latency and tokens on every request. Reading
--   its replies cannot show you that. Baseline scores were roughly
--   answer_correctness 1.0, tool_selection_accuracy 0.78, logical
--   consistency 0.73; giving the agent explicit routing instructions
--   took both process metrics to 1.0 and left correctness unchanged.
--
--   Do not "fix" SUPPORT_AGENT_V1. It is the baseline being measured.
--
-- The data is byte-for-byte lab 32's, including every hash seed, so the
-- planted Iberia P1 breach is identical and the two labs are directly
-- comparable.
--
-- Re-runnable: per-lab objects use CREATE OR REPLACE.
-- Teardown: labs/33-evaluate-a-cortex-agent/cleanup.sql
-- ============================================================

-- ------------------------------------------------------------
-- Per-user namespace
--
-- Every object this lab creates at ACCOUNT level -- the database and
-- the warehouse -- is suffixed with your user name, so a whole room
-- can run this lab in one Snowflake account without colliding.
-- Everything INSIDE the database keeps its usual name, so the SQL below
-- reads identically for everyone.
--
-- Two things worth knowing:
--   * Session variables live only for this session, so every file in
--     the workshop sets its own. Run the file top to bottom.
--   * CoCo runs its SQL in its own session, so it does NOT see these
--     variables. The last query in this file prints your real object
--     names -- paste those into a prompt rather than $LAB_DB.
-- ------------------------------------------------------------
SET NS            = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET WH            = 'COCO_WS_WH_' || $NS;
SET SHARED_DB     = 'COCO_WS_SHARED_DB_' || $NS;
SET SHARED_SCHEMA = $SHARED_DB || '.WORKSHOP';
SET RUN_LOG       = $SHARED_DB || '.WORKSHOP.LAB_RUN_LOG';
SET LAB_DB        = 'COCO_WS_LAB33_DB_' || $NS;

-- ------------------------------------------------------------
-- Shared bootstrap (safe to re-run, safe if another lab did it)
-- ------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS IDENTIFIER($WH)
  WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'CoCo Interactive Workshop -- shared compute for all labs';
USE WAREHOUSE IDENTIFIER($WH);

CREATE DATABASE IF NOT EXISTS IDENTIFIER($SHARED_DB)
  COMMENT = 'CoCo Interactive Workshop -- shared workshop metadata';
CREATE SCHEMA IF NOT EXISTS IDENTIFIER($SHARED_SCHEMA);
CREATE TABLE IF NOT EXISTS IDENTIFIER($RUN_LOG) (
  LAB_ID VARCHAR(16), LAB_NAME VARCHAR(200), EVENT_TYPE VARCHAR(20),
  EVENT_TS TIMESTAMP_LTZ, USER_NAME VARCHAR(200), ROLE_NAME VARCHAR(200),
  WAREHOUSE_NAME VARCHAR(200), SESSION_ID VARCHAR(50), QUERY_TAG VARCHAR(200)
);

ALTER SESSION SET QUERY_TAG = 'COCO_WS_LAB33';

-- ------------------------------------------------------------
-- Lab database
-- ------------------------------------------------------------
CREATE OR REPLACE DATABASE IDENTIFIER($LAB_DB)
  COMMENT = 'CoCo Workshop Lab 33 -- evaluate and improve a Cortex Agent';
USE DATABASE IDENTIFIER($LAB_DB);
CREATE OR REPLACE SCHEMA LAB;
USE SCHEMA LAB;

CREATE OR REPLACE TABLE POLICY_DOCS (
  DOC_ID     NUMBER(38,0) NOT NULL COMMENT 'Document identifier',
  DOC_TITLE  VARCHAR(200) NOT NULL COMMENT 'Document title',
  DOC_TYPE   VARCHAR(40)  NOT NULL COMMENT 'sla, refund, escalation or onboarding',
  UPDATED_ON DATE         NOT NULL COMMENT 'Last revision date',
  BODY       VARCHAR      NOT NULL COMMENT 'Full document text',
  CONSTRAINT PK_POLICY_DOCS PRIMARY KEY (DOC_ID)
) COMMENT = 'Internal support policy documents. The SLA targets exist only here, in prose.';

INSERT INTO POLICY_DOCS (DOC_ID, DOC_TITLE, DOC_TYPE, UPDATED_ON, BODY) VALUES
(1, 'Customer Support Service Level Agreement', 'sla', '2026-01-15',
 'This document defines the response and resolution commitments made to customers holding a standard support entitlement. ' ||
 'Tickets are triaged into three priorities at the point of creation. ' ||
 'Priority 1 (P1) covers a complete loss of service or a security incident affecting production. P1 tickets must be resolved within four hours of being opened. ' ||
 'Priority 2 (P2) covers degraded service where a documented workaround exists. P2 tickets must be resolved within twenty-four hours. ' ||
 'Priority 3 (P3) covers questions, feature requests and cosmetic defects. P3 tickets must be resolved within seventy-two hours. ' ||
 'Resolution time is measured in elapsed wall-clock hours from ticket creation to the ticket entering RESOLVED or CLOSED status. ' ||
 'Time spent waiting for customer response is NOT excluded from the measurement under the standard entitlement. ' ||
 'A region is considered in breach for a given quarter if more than five per cent of its tickets at any priority exceed the stated resolution target.'),
(2, 'Refund and Credit Policy', 'refund', '2025-11-02',
 'Refunds are issued at the discretion of the regional support manager. ' ||
 'Customers may request a service credit where a P1 incident exceeded its resolution target. ' ||
 'The standard credit is five per cent of the monthly subscription fee per breached P1 incident, capped at twenty-five per cent in any single month. ' ||
 'Credits are applied to the following invoice and are not paid as cash. ' ||
 'Requests must be submitted within thirty days of the incident being resolved.'),
(3, 'Escalation Procedure', 'escalation', '2026-02-20',
 'Any P1 ticket that has been open for more than two hours must be escalated to the regional duty manager. ' ||
 'If a P1 remains unresolved at three hours, the incident commander role is activated and the customer receives an hourly written update. ' ||
 'P2 tickets are escalated at twelve hours. P3 tickets are not escalated automatically. ' ||
 'Escalation does not change the resolution target; it changes who is accountable for meeting it.'),
(4, 'Support Analyst Onboarding', 'onboarding', '2025-09-08',
 'New analysts complete a two-week onboarding before taking live tickets. ' ||
 'Week one covers the product, the ticketing tool and the priority definitions. ' ||
 'Week two is shadowing an experienced analyst. ' ||
 'Analysts are expected to handle P3 tickets independently from week three, P2 from week five, and are not assigned P1 tickets until they have completed the incident response module.');

-- A search service so the agent has a retrieval tool for the prose.
CREATE OR REPLACE CORTEX SEARCH SERVICE POLICY_SEARCH
  ON BODY
  ATTRIBUTES DOC_TYPE, DOC_TITLE
  WAREHOUSE = $WH
  TARGET_LAG = '1 hour'
  COMMENT = 'Retrieval over internal support policy documents.'
  AS SELECT DOC_ID, DOC_TITLE, DOC_TYPE, BODY FROM POLICY_DOCS;

-- ------------------------------------------------------------
-- The structured half. Resolution times, no notion of a target.
--
-- Planted: Iberia breaches the 4-hour P1 target heavily. Every other
-- region stays comfortably inside all three targets.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE SUPPORT_TICKETS (
  TICKET_ID        NUMBER(38,0) NOT NULL COMMENT 'Ticket identifier',
  CUSTOMER_ID      NUMBER(38,0) NOT NULL COMMENT 'Customer identifier',
  REGION_NAME      VARCHAR(40)  NOT NULL COMMENT 'Support region handling the ticket',
  PRIORITY         VARCHAR(4)   NOT NULL COMMENT 'P1, P2 or P3',
  OPENED_AT        TIMESTAMP_NTZ NOT NULL COMMENT 'When the ticket was created',
  RESOLVED_AT      TIMESTAMP_NTZ COMMENT 'When it reached RESOLVED, NULL if still open',
  RESOLUTION_HOURS NUMBER(10,2) COMMENT 'Elapsed wall-clock hours to resolution',
  TICKET_STATUS    VARCHAR(12)  NOT NULL COMMENT 'RESOLVED, CLOSED or OPEN',
  CSAT_SCORE       NUMBER(2,0)  COMMENT 'Customer satisfaction 1-5, NULL if not surveyed',
  CONSTRAINT PK_SUPPORT_TICKETS PRIMARY KEY (TICKET_ID)
) COMMENT = 'Support tickets with resolution times. Contains no SLA targets -- those are in POLICY_DOCS.';

INSERT INTO SUPPORT_TICKETS
  (TICKET_ID, CUSTOMER_ID, REGION_NAME, PRIORITY, OPENED_AT, RESOLVED_AT,
   RESOLUTION_HOURS, TICKET_STATUS, CSAT_SCORE)
WITH t AS (
  SELECT
    SEQ4() + 1 AS TICKET_ID,
    1 + MOD(ABS(HASH(SEQ4(), 3)), 900) AS CUSTOMER_ID,
    DECODE(MOD(ABS(HASH(SEQ4(), 5)), 5), 0,'Northern Europe', 1,'Iberia',
           2,'Great Lakes', 3,'Pacific Rim', 'Gulf States') AS REGION_NAME,
    DECODE(MOD(ABS(HASH(SEQ4(), 7)), 10), 0,'P1', 1,'P1', 2,'P2', 3,'P2', 'P3') AS PRIORITY,
    DATEADD('hour', -1 * MOD(ABS(HASH(SEQ4(), 11)), 24 * 180),
            CURRENT_TIMESTAMP())::TIMESTAMP_NTZ AS OPENED_AT,
    SEQ4() AS S
  FROM TABLE(GENERATOR(ROWCOUNT => 6000))
),
sized AS (
  SELECT
    t.*,
    -- Base resolution comfortably inside target, then a heavy penalty
    -- for Iberia P1 so the breach is unambiguous.
    CASE t.PRIORITY
      WHEN 'P1' THEN
        CASE WHEN t.REGION_NAME = 'Iberia'
             -- Straddles the four-hour target on purpose: roughly half of
             -- Iberia's P1 tickets breach. A region where 100% breached would
             -- be unambiguous but would not look like a real support queue.
             THEN ROUND(0.5 + MOD(ABS(HASH(t.S, 13)), 750) / 100.0, 2)   -- 0.5 to 8.0 h
             ELSE ROUND(0.5 + MOD(ABS(HASH(t.S, 13)), 300) / 100.0, 2) END -- 0.5 to 3.5 h
      WHEN 'P2' THEN ROUND(2 + MOD(ABS(HASH(t.S, 17)), 1900) / 100.0, 2)   -- 2 to 21 h
      ELSE           ROUND(6 + MOD(ABS(HASH(t.S, 19)), 5500) / 100.0, 2)   -- 6 to 61 h
    END AS RES_HOURS
  FROM t
)
SELECT
  TICKET_ID,
  CUSTOMER_ID,
  REGION_NAME,
  PRIORITY,
  OPENED_AT,
  -- About 4% of tickets are still open.
  IFF(MOD(ABS(HASH(S, 23)), 25) = 0, NULL,
      DATEADD('minute', ROUND(RES_HOURS * 60), OPENED_AT)::TIMESTAMP_NTZ),
  IFF(MOD(ABS(HASH(S, 23)), 25) = 0, NULL, RES_HOURS),
  IFF(MOD(ABS(HASH(S, 23)), 25) = 0, 'OPEN',
      IFF(MOD(ABS(HASH(S, 29)), 3) = 0, 'CLOSED', 'RESOLVED')),
  IFF(MOD(ABS(HASH(S, 31)), 4) = 0, NULL, 1 + MOD(ABS(HASH(S, 37)), 5))
FROM sized;
-- ------------------------------------------------------------
-- A semantic view over the tickets, so the agent has an Analyst tool.
--
-- Deliberately honest: it models the ticket data accurately and says
-- nothing about SLA targets, because the ticket data contains none. An
-- agent that answers "did Iberia breach its SLA" from this view alone
-- is inventing the target, and that is the behaviour the evaluation is
-- meant to catch.
-- ------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW TICKETS_SV
  TABLES (
    tickets AS SUPPORT_TICKETS
      PRIMARY KEY (TICKET_ID)
      WITH SYNONYMS = ('support tickets', 'cases')
      COMMENT = 'One row per support ticket, with elapsed resolution hours.'
  )
  DIMENSIONS (
    tickets.region       AS REGION_NAME
      WITH SYNONYMS = ('support region', 'geo') COMMENT = 'Support region handling the ticket.',
    tickets.priority     AS PRIORITY
      WITH SYNONYMS = ('severity', 'p level') COMMENT = 'P1, P2 or P3, assigned at creation.',
    tickets.status       AS TICKET_STATUS
      WITH SYNONYMS = ('state') COMMENT = 'RESOLVED, CLOSED or OPEN.',
    tickets.opened_date  AS TO_DATE(OPENED_AT)
      WITH SYNONYMS = ('created date', 'open date') COMMENT = 'Date the ticket was opened.'
  )
  METRICS (
    tickets.ticket_count      AS COUNT(tickets.TICKET_ID)
      COMMENT = 'Number of tickets.',
    tickets.avg_resolution_hours AS AVG(tickets.RESOLUTION_HOURS)
      COMMENT = 'Mean elapsed wall-clock hours from open to resolved.',
    tickets.max_resolution_hours AS MAX(tickets.RESOLUTION_HOURS)
      COMMENT = 'Longest elapsed resolution time.',
    tickets.open_ticket_count AS COUNT_IF(tickets.TICKET_STATUS = 'OPEN')
      COMMENT = 'Tickets still open.'
  )
  COMMENT = 'Support ticket volumes and resolution times. Contains NO SLA targets.';

-- ------------------------------------------------------------
-- The agent under test.
--
-- Note what is missing from the instructions: any statement of which
-- tool answers which kind of question, and any instruction not to
-- assume an SLA target. The Analyst tool's description overreaches --
-- "support performance" sounds like it covers SLA compliance, and it
-- does not.
--
-- Do not "fix" this. It is the baseline the lab measures.
-- ------------------------------------------------------------
-- A tool_resources block has to name the semantic view, search service and
-- warehouse by their real, per-user names, and FROM SPECIFICATION takes a
-- literal $$ block that cannot see a session variable. So the statement is
-- assembled as a string and run with EXECUTE IMMEDIATE. There is no way around
-- this while the object names carry the user name.
SET AGENT_SPEC_SQL = 'CREATE OR REPLACE AGENT SUPPORT_AGENT_V1
  WITH PROFILE = ''{"display_name": "Support Agent v1 (baseline)"}''
  COMMENT = ''Lab 33 baseline agent. Deliberately under-instructed so evaluation has something to find.''
FROM SPECIFICATION $$
{
  "models": { "orchestration": "auto" },
  "instructions": {
    "response": "You are a support operations analyst. Answer questions about support performance clearly and concisely.",
    "sample_questions": [
      { "question": "How many P1 tickets did each region handle?" }
    ]
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "support_analyst",
        "description": "Query support performance data, including ticket volumes, resolution times and SLA compliance by region and priority."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "policy_search",
        "description": "Internal documents."
      }
    }
  ],
  "tool_resources": {
    "support_analyst": {
      "semantic_view": "' || $LAB_DB || '.LAB.TICKETS_SV",
      "execution_environment": { "type": "warehouse", "warehouse": "' || $WH || '" }
    },
    "policy_search": {
      "search_service": "' || $LAB_DB || '.LAB.POLICY_SEARCH",
      "max_results": 4,
      "title_column": "DOC_TITLE",
      "id_column": "DOC_ID"
    }
  }
}
$$';

EXECUTE IMMEDIATE $AGENT_SPEC_SQL;

-- ------------------------------------------------------------
-- The evaluation dataset.
--
-- Six queries, chosen to cover the four shapes that matter: one tool,
-- the other tool, both tools, and no tools at all. A dataset of only
-- happy-path questions cannot tell you that an agent reaches for the
-- wrong tool.
--
-- Ground truth is a VARIANT built with PARSE_JSON, not
-- OBJECT_CONSTRUCT: OBJECT_CONSTRUCT returns OBJECT, and the dataset
-- column has to be VARIANT. This is a documented gotcha and it fails
-- at dataset creation rather than at insert.
--
-- Every query is scoped to absolute dates. "Last quarter" would score
-- differently every time the lab is run, which is the documented cause
-- of ground-truth staleness.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE AGENT_EVAL_INPUTS (
  INPUT_QUERY  VARCHAR NOT NULL COMMENT 'The user question to evaluate.',
  GROUND_TRUTH VARIANT NOT NULL COMMENT 'Expected output and expected tool invocations.'
) COMMENT = 'Evaluation inputs for SUPPORT_AGENT_V1.';

-- 1. Needs BOTH tools: the target is in prose, the breach count is in the data.
INSERT INTO AGENT_EVAL_INPUTS SELECT
  'Which support region is in breach of the P1 resolution target, and what is that target?',
  PARSE_JSON('{
    "ground_truth_output": "The response must state that the P1 resolution target is four hours, and must attribute that target to the Service Level Agreement document rather than presenting it as an assumption. It must identify Iberia as the region in breach, and should note that a region is in breach when more than five per cent of its tickets at a priority exceed the target. Iberia should be reported with a P1 breach rate far above five per cent; other regions should be reported at or near zero. The response must not invent a different target such as 24 hours, and must not claim the target is unavailable.",
    "ground_truth_invocations": [
      { "tool_name": "policy_search",
        "tool_input": "P1 resolution target and the definition of SLA breach",
        "tool_output": "Should retrieve the Service Level Agreement document and surface the four-hour P1 target and the five per cent breach threshold." },
      { "tool_name": "support_analyst",
        "tool_input": "P1 tickets per region and how many exceeded four hours",
        "tool_output": "SQL over the ticket data grouping P1 tickets by region and counting those with resolution hours above four; Iberia should stand out." }
    ]
  }');

-- 2. Prose only. The number exists nowhere in the ticket data.
INSERT INTO AGENT_EVAL_INPUTS SELECT
  'What service credit is a customer entitled to when a P1 incident misses its resolution target?',
  PARSE_JSON('{
    "ground_truth_output": "The response must state that the standard credit is five per cent of the monthly subscription fee per breached P1 incident, capped at twenty-five per cent in any single month, that credits are applied to the following invoice rather than paid in cash, and that requests must be submitted within thirty days of the incident being resolved. It must not invent a different percentage or cap.",
    "ground_truth_invocations": [
      { "tool_name": "policy_search",
        "tool_input": "service credit for a breached P1 incident",
        "tool_output": "Should retrieve the Refund and Credit Policy and surface the five per cent per incident and twenty-five per cent monthly cap." }
    ]
  }');

-- 3. Data only. No policy question is being asked.
INSERT INTO AGENT_EVAL_INPUTS SELECT
  'How many support tickets are still open, broken down by region?',
  PARSE_JSON('{
    "ground_truth_output": "The response must give a per-region count of tickets whose status is OPEN, covering all five regions (Northern Europe, Iberia, Great Lakes, Pacific Rim, Gulf States). Roughly four per cent of all tickets are open, so the total across regions should be in the low hundreds out of six thousand tickets. It must present the counts as facts derived from the data and must not describe the figures as unavailable.",
    "ground_truth_invocations": [
      { "tool_name": "support_analyst",
        "tool_input": "count of tickets with status OPEN grouped by region",
        "tool_output": "SQL counting open tickets by region, returning five rows." }
    ]
  }');

-- 4. Prose only, and specifically NOT the SLA document.
INSERT INTO AGENT_EVAL_INPUTS SELECT
  'At what point must a P1 ticket be escalated, and who is accountable after that?',
  PARSE_JSON('{
    "ground_truth_output": "The response must state that a P1 ticket open for more than two hours is escalated to the regional duty manager, and that at three hours the incident commander role is activated and the customer receives an hourly written update. It should note that escalation does not change the resolution target, only who is accountable for meeting it. It must not conflate the two-hour escalation trigger with the four-hour resolution target.",
    "ground_truth_invocations": [
      { "tool_name": "policy_search",
        "tool_input": "P1 escalation timing and accountability",
        "tool_output": "Should retrieve the Escalation Procedure document and surface the two-hour and three-hour thresholds." }
    ]
  }');

-- 5. Both tools, and a trap inside the trap: average resolution time looks
--    fine for Iberia even though half its P1 tickets breach.
INSERT INTO AGENT_EVAL_INPUTS SELECT
  'Is Iberia meeting its P1 commitments? Explain how you decided.',
  PARSE_JSON('{
    "ground_truth_output": "The response must conclude that Iberia is NOT meeting its P1 commitments, and must justify that against the four-hour target taken from the Service Level Agreement rather than an assumed one. A correct answer reasons about the proportion of P1 tickets exceeding four hours, not only the average resolution time -- Iberia''s average P1 time sits near the target while a large share of individual tickets exceed it, so an answer resting on the average alone is wrong even if it reaches the right verdict by luck. It must not state that Iberia is compliant.",
    "ground_truth_invocations": [
      { "tool_name": "policy_search",
        "tool_input": "P1 resolution target and breach definition",
        "tool_output": "Should retrieve the four-hour P1 target and the five per cent breach threshold." },
      { "tool_name": "support_analyst",
        "tool_input": "Iberia P1 tickets, resolution hours, and how many exceed four hours",
        "tool_output": "SQL over Iberia P1 tickets returning both the average resolution time and the count or share above four hours." }
    ]
  }');

-- 6. Out of scope. The expected tool list is empty, which is what
--    tool_selection_accuracy scores an unnecessary tool call against.
INSERT INTO AGENT_EVAL_INPUTS SELECT
  'What is the weather forecast for Madrid tomorrow?',
  PARSE_JSON('{
    "ground_truth_output": "The response must state that weather information is outside what this agent can answer, and should say what it can help with instead -- support ticket data and internal support policy. It must not fabricate a forecast, a temperature or a condition.",
    "ground_truth_invocations": []
  }');

-- ------------------------------------------------------------
-- Where the evaluation config lives.
--
-- The file format is not optional and not obvious: an evaluation YAML
-- read with default CSV settings is mangled, and the error you get
-- points at the YAML rather than at the format.
-- ------------------------------------------------------------
CREATE OR REPLACE FILE FORMAT YAML_FILE_FORMAT
  TYPE = 'CSV'
  FIELD_DELIMITER = NONE
  RECORD_DELIMITER = '\n'
  SKIP_HEADER = 0
  FIELD_OPTIONALLY_ENCLOSED_BY = NONE
  ESCAPE_UNENCLOSED_FIELD = NONE
  COMMENT = 'Required so Snowflake parses an evaluation YAML unaltered.';

CREATE OR REPLACE STAGE EVAL_CONFIG
  FILE_FORMAT = YAML_FILE_FORMAT
  COMMENT = 'Holds the agent evaluation configuration YAML.';

-- ------------------------------------------------------------
-- Register this run for the Lab 62 cost capstone
-- ------------------------------------------------------------
INSERT INTO IDENTIFIER($RUN_LOG)
  (LAB_ID, LAB_NAME, EVENT_TYPE, EVENT_TS, USER_NAME, ROLE_NAME,
   WAREHOUSE_NAME, SESSION_ID, QUERY_TAG)
SELECT 'LAB33', 'Evaluate a Cortex Agent', 'SETUP',
       CURRENT_TIMESTAMP(), CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(),
       CURRENT_SESSION(), CURRENT_QUERY_TAG();

-- ------------------------------------------------------------
-- Confirm, and print the answer key.
--
-- Iberia should be far above the five per cent breach threshold and
-- everyone else at zero. Note Iberia's AVG_P1_HOURS: it sits close to
-- the four-hour target even though about half its tickets breach,
-- which is why an agent that reasons from the average alone gets the
-- wrong answer for the right-looking reason.
-- ------------------------------------------------------------
SELECT
  (SELECT COUNT(*) FROM POLICY_DOCS)        AS POLICY_DOCS,
  (SELECT COUNT(*) FROM SUPPORT_TICKETS)    AS TICKETS,
  (SELECT COUNT(*) FROM AGENT_EVAL_INPUTS)  AS EVAL_INPUTS;

SELECT
  REGION_NAME,
  COUNT(*)                                                     AS P1_TICKETS,
  COUNT_IF(RESOLUTION_HOURS > 4)                               AS P1_BREACHES,
  ROUND(100.0 * COUNT_IF(RESOLUTION_HOURS > 4) / COUNT(*), 1)   AS P1_BREACH_PCT,
  ROUND(AVG(RESOLUTION_HOURS), 2)                              AS AVG_P1_HOURS
FROM SUPPORT_TICKETS
WHERE PRIORITY = 'P1' AND RESOLUTION_HOURS IS NOT NULL
GROUP BY REGION_NAME
ORDER BY P1_BREACH_PCT DESC;

-- ------------------------------------------------------------
-- Your object names, for pasting into CoCo and into the evaluation YAML
-- ------------------------------------------------------------
SELECT $LAB_DB                          AS YOUR_LAB_DATABASE,
       $LAB_DB || '.LAB'                AS YOUR_LAB_SCHEMA,
       $LAB_DB || '.LAB.SUPPORT_AGENT_V1' AS YOUR_AGENT,
       $LAB_DB || '.LAB.EVAL_CONFIG'    AS YOUR_CONFIG_STAGE,
       $WH                              AS YOUR_WAREHOUSE;
