# Local unit tests and isolated Home Assistant checks

The existing `.venv` remains the lightweight unit-test environment. Run its
checks with `.venv/bin/python -m pytest -q`; no home or physical device is used.

The separate ignored `.venv-ha` is the full Python 3.14 Home Assistant harness,
matching the CI runtime job. `requirements-ha.txt` pins its packages and hashes,
including the existing CI-only Pillow/uv security overrides. This is a test
installation only; it does not change an installed Home Assistant server.

Run inside VM development (`dev bash`); check that the project environment exists:

```bash
cd /home/dev/projects/FanControl
.venv-ha/bin/python scripts/check_test_dependencies.py
.venv-ha/bin/python scripts/runtime_check.py
```

The runtime check boots a temporary loopback-only HA instance with synthetic
users/entities; it neither connects to a home nor calls a physical device.
Its temporary configuration is removed when the check finishes. Integration and
network dependencies are preinstalled by the lock; runtime package installation
is disabled so HA cannot replace the security overrides while booting. Run the
dependency validator both before and after runtime checks.

To recreate this environment inside VM development with installed Python 3.14:

```bash
uv venv \
  --python python3.14 .venv-ha
uv pip sync \
  --python .venv-ha/bin/python --require-hashes requirements-ha.txt
```

To refresh its lock, use `uv pip compile --python .venv-ha/bin/python
--override scripts/ha-test-overrides.txt --generate-hashes requirements-ha.in
-o requirements-ha.txt`. Keep the override validator passing; raw `pip check`
reports the two intentionally overridden upstream exact pins.
