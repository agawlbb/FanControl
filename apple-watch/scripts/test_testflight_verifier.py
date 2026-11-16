"""Test Apple relationship responses without a credential or network connection."""
import ast
import base64
import json
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import urllib.parse
import urllib.request


class Response:
    def __init__(self, content): self.content = content
    def __enter__(self): return self
    def __exit__(self, *args): pass
    def read(self): return self.content


class VerifierTests(unittest.TestCase):
    def test_empty_relationship_response_and_json_reads(self):
        tree = ast.parse(Path(__file__).with_name('check_testflight.py').read_text())
        function = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == 'request')
        run = lambda *args, **kwargs: SimpleNamespace(stdout=b'\x30\x06\x02\x01\x01\x02\x01\x01')
        namespace = {'base64':base64, 'json':json, 'os':os, 'time':SimpleNamespace(time=lambda:1000),
                     'subprocess':SimpleNamespace(run=run), 'urllib':urllib}
        exec(compile(ast.Module(body=[function], type_ignores=[]), '<request>', 'exec'), namespace)
        with patch.dict(os.environ, {'ASC_KEY_ID':'synthetic', 'ASC_ISSUER_ID':'synthetic', 'ASC_KEY_PATH':'synthetic'}):
            with patch.object(urllib.request, 'urlopen', return_value=Response(b'')) as open_url:
                self.assertEqual(namespace['request']('betaGroups/synthetic/relationships/builds', {'data':[]}), {})
                self.assertEqual(open_url.call_args.args[0].get_method(), 'POST')
            with patch.object(urllib.request, 'urlopen', return_value=Response(b'{"data":[]}')):
                self.assertEqual(namespace['request']('builds'), {'data':[]})


if __name__ == '__main__': unittest.main()
