"""Utility scratchpad, independent of Snowflake."""
def safe_ratio(numerator, denominator):
    return numerator / denominator if denominator else None
