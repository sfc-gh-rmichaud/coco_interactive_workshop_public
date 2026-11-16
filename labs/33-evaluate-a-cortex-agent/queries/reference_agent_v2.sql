-- ============================================================
-- reference_agent_v2.sql -- Lab 33, presenter reference
--
-- The improved agent. This is what step 4 asks CoCo to produce, and it
-- is here so a presenter can show the answer or recover a stuck room.
-- Do not hand it to attendees before they have tried.
--
-- What changed from SUPPORT_AGENT_V1, and why each change targets a
-- metric the baseline run actually lost points on:
--
--   1. An `orchestration` instruction that says which tool answers
--      which kind of question, and explicitly tells the agent not to
--      call a tool it does not need. The baseline scored 0.5 on
--      "how many tickets are still open" because it called the
--      retrieval tool as well as the Analyst tool -- one matched
--      expected tool over two actual calls. Tool selection accuracy
--      penalises extra calls exactly as hard as missing ones.
--
--   2. Honest tool descriptions. The baseline described the Analyst
--      tool as covering "SLA compliance", which it cannot: the ticket
--      data holds no targets. That description is what invites the
--      agent to answer a policy question from the numbers.
--
--   3. A response instruction that forbids assuming a target and
--      requires the breach SHARE rather than the average. Iberia's
--      average P1 time is 4.34 hours against a four-hour target, so an
--      answer resting on the average alone lands on the right verdict
--      for the wrong reason and falls apart on any region whose
--      average sits below target while individual tickets breach.
--
--   4. Sample questions covering all three shapes -- data only, policy
--      only, and both -- which is planning context the baseline lacked.
-- ============================================================

SET NS     = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET WH     = 'COCO_WS_WH_' || $NS;
SET LAB_DB = 'COCO_WS_LAB33_DB_' || $NS;

USE WAREHOUSE IDENTIFIER($WH);
USE DATABASE IDENTIFIER($LAB_DB);
USE SCHEMA LAB;

-- Same EXECUTE IMMEDIATE pattern as setup.sql, and for the same reason:
-- FROM SPECIFICATION is a literal block that cannot see a session variable,
-- and the tool resources have to name the per-user objects.
SET AGENT_V2_SQL = 'CREATE OR REPLACE AGENT SUPPORT_AGENT_V2
  WITH PROFILE = ''{"display_name": "Support Agent v2 (instructed)"}''
  COMMENT = ''Lab 33 improved agent. Tool routing made explicit; tool descriptions corrected.''
FROM SPECIFICATION $$
{
  "models": { "orchestration": "auto" },
  "instructions": {
    "response": "You are a support operations analyst. Answer only from the tools available to you. Never state or assume a service level target that you have not retrieved from the policy documents -- if you need a target, look it up. When judging whether a region meets a target, report the SHARE of tickets that exceeded it, not only the average resolution time, because an average can sit inside a target while many individual tickets breach it. Cite the policy document by name when you rely on it. If a question is outside support ticket data and support policy, say so plainly and do not answer it.",
    "orchestration": "Route by where the answer actually lives.\\n\\nUse policy_search for anything defined in writing: resolution targets, what counts as a breach, escalation timings, refund and credit rules, onboarding rules. None of these exist in the ticket data.\\n\\nUse support_analyst for anything counted or measured: ticket volumes, resolution hours, open tickets, breakdowns by region, priority or date. It has no notion of a target.\\n\\nUse BOTH, and combine them, when a question compares measured behaviour against a written rule -- for example whether a region is in breach. Retrieve the rule first, then measure against it.\\n\\nDo not call a tool whose answer you do not need. A question purely about counts needs no document retrieval, and a question purely about policy needs no query.",
    "sample_questions": [
      { "question": "How many P1 tickets did each region handle?" },
      { "question": "What is the P1 resolution target?" },
      { "question": "Which region is in breach of the P1 target?" }
    ]
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "support_analyst",
        "description": "Query the support ticket table: ticket counts, priorities, regions, statuses, open dates and elapsed resolution hours. Use for anything measured or counted. This data contains NO service level targets and cannot answer whether a target was met on its own."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "policy_search",
        "description": "Search internal support policy documents: the Service Level Agreement (resolution targets by priority, and the definition of a breach), the Refund and Credit Policy, the Escalation Procedure, and analyst onboarding. Use for any rule, target, threshold or entitlement. These documents are the ONLY place service level targets are written down."
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

EXECUTE IMMEDIATE $AGENT_V2_SQL;

SHOW AGENTS IN SCHEMA;
