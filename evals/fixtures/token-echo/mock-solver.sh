#!/usr/bin/env bash
# Deterministic TB2a mock solver: apply the known SUT fix (no LLM).
# Invoked with cwd = fixture workspace; optional prompt path as $1 (ignored).
set -euo pipefail
cat >sut.sh <<'EOF'
#!/usr/bin/env bash
# Fixed SUT for TB1 golden / mock-solver path.
set -euo pipefail
printf 'FIXTURE_OK\n'
EOF
chmod +x sut.sh
printf 'mock-solver: wrote FIXTURE_OK sut.sh\n'
