"""Write a local deploy manifest from explicitly supplied, verified identifiers."""
import argparse
from pathlib import Path
import re


def identifier(value):
    if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', value):
        raise argparse.ArgumentTypeError('Use an unquoted Snowflake identifier')
    return value.upper()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('database', 'schema', 'warehouse', 'compute-pool'):
        parser.add_argument('--' + name, required=True, type=identifier)
    options = parser.parse_args()
    manifest = f'''definition_version: 2
entities:
  usage_dashboard:
    type: streamlit
    identifier:
      name: USAGE_DASHBOARD
      database: {options.database}
      schema: {options.schema}
    query_warehouse: {options.warehouse}
    runtime_name: SYSTEM$ST_CONTAINER_RUNTIME_PY3_11
    compute_pool: {options.compute_pool}
    main_file: streamlit_app.py
    artifacts:
      - streamlit_app.py
      - sources.py
'''
    Path(__file__).with_name('snowflake.yml').write_text(manifest)
    print('Wrote snowflake.yml. Deploy only after reviewing the target and artifacts.')
