# Local unit tests and isolated Home Assistant checks

The existing `.venv` remains the lightweight unit-test environment. Run its
checks with `.venv/bin/python -m pytest -q`; no home or physical device is used.

The separate ignored `.venv-ha` is the full Python 3.14 Home Assistant harness,
matching the CI runtime job. `requirements-ha.txt` pins its packages and hashes,
including the existing CI-only Pillow/uv security overrides. This is a test
installation only; it does not change an installed Home Assistant server.

The VPS environment is prepared. Run:

```bash
cd /home/debian/projects/fancontrol/ha-integration
.venv-ha/bin/python scripts/check_test_dependencies.py
.venv-ha/bin/python scripts/runtime_check.py
```

The runtime check boots a temporary loopback-only HA instance with synthetic
users/entities; it neither connects to a home nor calls a physical device.
Its temporary configuration is removed when the check finishes.

To recreate this environment on the VPS:

```bash
/home/debian/projects/.dev-tools/bootstrap/bin/uv venv \
  --python /home/debian/projects/.dev-tools/python/cpython-3.14.8-linux-x86_64-gnu/bin/python .venv-ha
/home/debian/projects/.dev-tools/bootstrap/bin/uv pip sync \
  --python .venv-ha/bin/python --require-hashes requirements-ha.txt
```

To refresh its lock, use `uv pip compile --python .venv-ha/bin/python
--override scripts/ha-test-overrides.txt --generate-hashes requirements-ha.in
-o requirements-ha.txt`. Keep the override validator passing; raw `pip check`
reports the two intentionally overridden upstream exact pins.
