"""Local app checks with a fake Snowflake connection; no live data required."""
from datetime import date
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
import pandas as pd
from streamlit.testing.v1 import AppTest

sys.path.insert(0,str(Path(__file__).parent))
from sources import SOURCES, status_for_error, validate_window


class FakeConnection:
    def __init__(self, denied=False):
        self.denied = denied
    def query(self, sql, **kwargs):
        if 'CURRENT_ACCOUNT_NAME' in sql:
            return pd.DataFrame([{'ACCOUNT':'TEST','ROLE_NAME':'TEST_ROLE','USER_NAME':'TEST_USER'}])
        if self.denied:
            raise RuntimeError('Insufficient privileges')
        return pd.DataFrame(columns=['DAY','SERVICE_TYPE','CREDITS_USED','ADJUSTMENT','CREDITS_BILLED'])


class AppTests(unittest.TestCase):
    def test_demo(self):
        app = AppTest.from_file(str(Path(__file__).with_name('streamlit_app.py'))).run()
        self.assertFalse(app.exception)
        self.assertEqual([item.value for item in app.metric],['29.0000','-2.0000','27.0000'])

    def test_empty_and_denied(self):
        for denied in (False,True):
            with patch('streamlit.connection',return_value=FakeConnection(denied)):
                app = AppTest.from_file(str(Path(__file__).with_name('streamlit_app.py'))).run()
                app.sidebar.button[0].click().run()
                app.sidebar.radio[0].set_value('Live').run()
                self.assertFalse(app.exception)
                if denied:
                    self.assertTrue(any('Permission denied' in message.value for message in app.error))
                else:
                    self.assertTrue(any('No rows' in message.value for message in app.info))
                self.assertEqual(len(app.metric),0)

    def test_sources(self):
        for source in SOURCES.values():
            self.assertEqual(source.sql().count('?'),2)
            self.assertIn('LIMIT 5000',source.sql())
        self.assertNotIn('SUM(CREDITS)',SOURCES['REST inference'].sql())
        self.assertEqual(status_for_error(Exception('does not exist or not authorized')),
                         'Unavailable or not authorized (ask admin to distinguish)')
        with self.assertRaises(ValueError):
            validate_window(date(2026,1,1),date(2026,3,1))


if __name__=='__main__':
    unittest.main()
