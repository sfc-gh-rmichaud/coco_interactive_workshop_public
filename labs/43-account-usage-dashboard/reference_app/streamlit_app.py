"""Account usage workshop app, adapted from Snowflake's compute dashboard scaffold."""
from datetime import date, datetime, timedelta, timezone
import os
import pandas as pd
import streamlit as st
from sources import SOURCES, validate_window, status_for_error

st.set_page_config(page_title='Account usage', layout='wide')
st.title('Account usage')
st.caption('Credits, tokens and bytes are separate measures. Service drill-downs overlap; never add them together.')
mode = st.sidebar.radio('Data source', ['Demo', 'Live'], key='mode')
section = st.sidebar.radio('Section', ['Overview', 'AI', 'Compute', 'Storage and transfer', 'Coverage'])
start = st.sidebar.date_input('Start (inclusive)', date.today() - timedelta(days=7))
end = st.sidebar.date_input('End (exclusive)', date.today())
if st.sidebar.button('Refresh queries'):
    st.cache_data.clear()
try:
    validate_window(start, end)
except ValueError as error:
    st.error(str(error))
    st.stop()


@st.cache_data(ttl=300, max_entries=64, show_spinner='Querying bounded aggregate...')
def load_source(source_name, start_date, end_date, connection_name, identity):
    connection = st.connection('snowflake')
    frame = connection.query(SOURCES[source_name].sql(), params=[start_date, end_date], ttl=0)
    frame.columns = frame.columns.str.upper()
    return frame, datetime.now(timezone.utc).isoformat()


def display(frame, source_name):
    if frame.empty:
        st.info('No rows reported in this window. Check source latency before interpreting this as no usage.')
        return
    if len(frame) == 5000:
        st.warning('Result hit the display limit. Narrow the window; displayed totals may be incomplete.')
    if source_name == 'Overview':
        selected = st.multiselect('Service types', sorted(frame.SERVICE_TYPE.unique()), sorted(frame.SERVICE_TYPE.unique()))
        frame = frame[frame.SERVICE_TYPE.isin(selected)]
        if frame.empty:
            st.info('No service types selected.')
            return
        columns = st.columns(3)
        for column, field, label in zip(columns, ['CREDITS_USED', 'ADJUSTMENT', 'CREDITS_BILLED'], ['Gross credits', 'Cloud adjustment', 'Billed credits']):
            column.metric(label, f'{pd.to_numeric(frame[field]).sum(min_count=1):,.4f}')
        chart = frame.pivot_table(index='DAY', columns='SERVICE_TYPE', values='CREDITS_BILLED', aggfunc='sum')
        st.bar_chart(chart)
    st.dataframe(frame, hide_index=True)
    st.download_button('Download these aggregates', frame.to_csv(index=False), file_name='usage-aggregates.csv', mime='text/csv')


coverage = pd.DataFrame([{'Source': name, 'View': source.view, 'Unit': source.unit,
    'Latency guidance': source.latency, 'Dimensions': source.dimensions,
    'Access': 'SNOWFLAKE.USAGE_VIEWER; verify in your account', 'Total rule': source.note}
    for name, source in SOURCES.items()])
if section == 'Coverage':
    st.dataframe(coverage, hide_index=True)
    st.info('Coverage is a source inventory, not a successful access test. Select a source in Live mode to probe it. Other metered services appear automatically in Overview; new product drill-downs require reviewed adapters.')
    st.stop()
if mode == 'Demo':
    st.warning('DEMO ONLY: synthetic January 2026 metering. Date controls do not filter this fixed teaching fixture. No live account queries run.')
    if section != 'Overview':
        st.info('Demo contains only the overview reconciliation fixture. Select Live for real service coverage; missing demo detail is not zero usage.')
        st.stop()
    frame = pd.DataFrame([
        ['2026-01-01','WAREHOUSE_METERING',12,-1,11], ['2026-01-01','AI_SERVICES',3,0,3],
        ['2026-01-02','WAREHOUSE_METERING',10,-1,9], ['2026-01-02','AI_SERVICES',4,0,4]],
        columns=['DAY','SERVICE_TYPE','CREDITS_USED','ADJUSTMENT','CREDITS_BILLED'])
    display(frame, 'Overview')
    st.stop()

connection_name = os.getenv('SNOWFLAKE_DEFAULT_CONNECTION_NAME') or 'default'
try:
    connection = st.connection('snowflake')
    identity_frame = connection.query('SELECT CURRENT_ACCOUNT_NAME() AS ACCOUNT, CURRENT_ROLE() AS ROLE_NAME, CURRENT_USER() AS USER_NAME', ttl=0)
    identity = tuple(str(value) for value in identity_frame.iloc[0])
except Exception as error:
    st.error(status_for_error(error))
    st.stop()
st.caption('Execution context: ' + ' / '.join(identity))
st.warning('This app may execute with its owner role. Share only with audiences authorized to see account-wide telemetry. No role switching is performed here.')
choices = {'Overview':['Overview'], 'AI':list(SOURCES)[1:11],
           'Compute':['Warehouse compute'],
           'Storage and transfer':['Storage','Network transfer','Database replication','Group replication']}
source_name = st.selectbox('Telemetry source', choices[section])
source = SOURCES[source_name]
st.caption(f'Source: SNOWFLAKE.ACCOUNT_USAGE.{source.view} | {source.unit} | Latency: {source.latency}')
st.caption(source.note)
with st.expander('SQL and window'):
    st.code(source.sql(), language='sql')
    st.write('Bound values:', str(start), str(end))
try:
    frame, queried_at = load_source(source_name, start, end, connection_name, identity)
except Exception as error:
    st.error(status_for_error(error))
    st.caption('No synthetic fallback and no zero substitution. Ask an administrator to verify grants and source availability.')
else:
    st.caption(f'Queried at {queried_at}; latest reported day: {frame.DAY.max() if not frame.empty else "none"}. This is not a freshness guarantee.')
    display(frame, source_name)
