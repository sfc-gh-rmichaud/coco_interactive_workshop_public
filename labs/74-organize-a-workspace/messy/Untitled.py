"""Read the sibling saved query; moving just this file breaks the reference."""
from pathlib import Path
query = Path(__file__).with_name('Untitled.sql').read_text()
print(query)  # Prints SQL; does not submit it to Snowflake.
