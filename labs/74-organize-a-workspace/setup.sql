-- Trap: organizing files is not permission to execute their contents.
-- This browser-only lab needs no database, warehouse or run-log mutation.
SELECT CURRENT_ACCOUNT_NAME() AS ACCOUNT, CURRENT_USER() AS ATTENDEE,
       'Create a disposable private workspace named COCO_WS_LAB74_PRACTICE in Snowsight' AS NEXT_STEP;
