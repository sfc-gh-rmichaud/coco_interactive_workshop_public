"""Allowlisted, bounded source queries. Drill-downs must NEVER be added to overview."""
from dataclasses import dataclass


@dataclass(frozen=True)
class Source:
    view: str
    time: str
    dimensions: str
    measures: str
    unit: str
    latency: str
    note: str = 'Drill-down only; not additive to overview or other AI views'

    def sql(self):
        return (f'SELECT {self.time}::DATE AS DAY, {self.dimensions}, {self.measures} '
                f'FROM SNOWFLAKE.ACCOUNT_USAGE.{self.view} '
                f'WHERE {self.time} >= ? AND {self.time} < ? '
                'GROUP BY ALL ORDER BY DAY LIMIT 5000')


SOURCES = {
 'Overview': Source('METERING_DAILY_HISTORY', 'USAGE_DATE', 'SERVICE_TYPE',
    'SUM(CREDITS_USED) AS CREDITS_USED, SUM(CREDITS_USED_COMPUTE) AS COMPUTE_CREDITS, '
    'SUM(CREDITS_USED_CLOUD_SERVICES) AS CLOUD_SERVICES_CREDITS, '
    'SUM(CREDITS_ADJUSTMENT_CLOUD_SERVICES) AS ADJUSTMENT, SUM(CREDITS_BILLED) AS CREDITS_BILLED',
    'credits', '3h; cloud adjustments may take longer', 'Authoritative metered credit summary; not a currency invoice'),
 'CoCo': Source('SNOWFLAKE_COCO_USAGE_HISTORY','USAGE_TIME','INTERFACE',
    'SUM(TOKEN_CREDITS) AS CREDITS, SUM(TOKENS) AS TOKENS','credits / tokens','1h'),
 'Agents': Source('CORTEX_AGENT_USAGE_HISTORY','START_TIME','AGENT_NAME',
    'SUM(TOKEN_CREDITS) AS CREDITS, SUM(TOKENS) AS TOKENS','credits / tokens','1h'),
 'CoWork': Source('SNOWFLAKE_COWORK_USAGE_HISTORY','START_TIME','SNOWFLAKE_COWORK_NAME',
    'SUM(TOKEN_CREDITS) AS CREDITS, SUM(TOKENS) AS TOKENS','credits / tokens','1h'),
 'Analyst': Source('CORTEX_ANALYST_USAGE_HISTORY','START_TIME',"'direct Analyst' AS PRODUCT",
    'SUM(CREDITS) AS CREDITS, SUM(REQUEST_COUNT) AS REQUESTS','credits / requests; tokens not exposed','1h'),
 'AI functions': Source('CORTEX_AI_FUNCTIONS_USAGE_HISTORY','START_TIME','FUNCTION_NAME, MODEL_NAME',
    "SUM(CREDITS) AS CREDITS, SUM(GET(FILTER(METRICS, x -> x:key:metric::STRING = 'input' AND x:key:unit::STRING = 'tokens'),0):value::NUMBER) AS INPUT_TOKENS, "
    "SUM(GET(FILTER(METRICS, x -> x:key:metric::STRING = 'output' AND x:key:unit::STRING = 'tokens'),0):value::NUMBER) AS OUTPUT_TOKENS",
    'credits / reported input and output tokens; null = not reported','5m'),
 'Search': Source('CORTEX_SEARCH_DAILY_USAGE_HISTORY','USAGE_DATE','SERVICE_NAME, CONSUMPTION_TYPE',
    'SUM(CREDITS) AS CREDITS, SUM(TOKENS) AS TOKENS','credits / embedding tokens; serving has no token quantity','3h'),
 'REST inference': Source('CORTEX_REST_API_USAGE_HISTORY','START_TIME','MODEL_NAME',
    'SUM(TOKENS) AS TOKENS','tokens only; credits unavailable in this view','Check view documentation'),
 'Model training': Source('CORTEX_FINE_TUNING_USAGE_HISTORY','START_TIME','MODEL_NAME',
    'SUM(TOKEN_CREDITS) AS CREDITS, SUM(TOKENS) AS TOKENS','credits / tokens','1h'),
 'Provisioned capacity': Source('CORTEX_PROVISIONED_THROUGHPUT_USAGE_HISTORY','INTERVAL_START_TIME','MODEL_NAME, AI_SERVICE',
    'SUM(PTU_CREDITS) AS CREDITS','capacity credits; no request tokens','Check view documentation'),
 'Guardrails': Source('CORTEX_AI_GUARDRAILS_USAGE_HISTORY','USAGE_TIME','AGENTIC_SOURCE',
    'SUM(TOKEN_CREDITS) AS CREDITS, SUM(TOKENS) AS TOKENS','credits / tokens','Check view documentation'),
 'Warehouse compute': Source('WAREHOUSE_METERING_HISTORY','START_TIME','WAREHOUSE_NAME',
    'SUM(CREDITS_USED_COMPUTE) AS COMPUTE_CREDITS, SUM(CREDITS_USED_CLOUD_SERVICES) AS CLOUD_SERVICES_CREDITS',
    'gross credits; cloud adjustment is in overview','3h / cloud services 6h'),
 'Storage': Source('STORAGE_USAGE','USAGE_DATE',"'account storage' AS SCOPE",
    'AVG(STORAGE_BYTES) AS DATABASE_BYTES, AVG(STAGE_BYTES) AS STAGE_BYTES, AVG(FAILSAFE_BYTES) AS FAILSAFE_BYTES, '
    'AVG(HYBRID_TABLE_STORAGE_BYTES) AS HYBRID_BYTES, AVG(ARCHIVE_STORAGE_COOL_BYTES) AS COOL_BYTES, '
    'AVG(ARCHIVE_STORAGE_COLD_BYTES) AS COLD_BYTES',
    'daily average bytes, not cumulative bytes or credits','2h'),
 'Network transfer': Source('DATA_TRANSFER_HISTORY','START_TIME','SOURCE_CLOUD, TARGET_CLOUD, TARGET_REGION, TRANSFER_TYPE',
    'SUM(BYTES_TRANSFERRED) AS BYTES_TRANSFERRED','bytes, not credits','2h'),
 'Database replication': Source('REPLICATION_USAGE_HISTORY','START_TIME','DATABASE_NAME',
    'SUM(CREDITS_USED) AS CREDITS, SUM(BYTES_TRANSFERRED) AS BYTES_TRANSFERRED','credits / bytes','3h'),
 'Group replication': Source('REPLICATION_GROUP_USAGE_HISTORY','START_TIME','REPLICATION_GROUP_NAME',
    'SUM(CREDITS_USED) AS CREDITS, SUM(BYTES_TRANSFERRED) AS BYTES_TRANSFERRED','credits / bytes','3h'),
}


def validate_window(start, end):
    if not 0 < (end - start).days <= 30:
        raise ValueError('Choose an end-exclusive range of 1 to 30 days')


def status_for_error(error):
    # Snowflake intentionally combines missing-object and unauthorized errors.
    message = str(error).lower()
    if 'not authorized' in message or 'does not exist' in message:
        return 'Unavailable or not authorized (ask admin to distinguish)'
    if 'privilege' in message or 'permission' in message:
        return 'Permission denied'
    return 'Query failed; inspect source/version with administrator'
