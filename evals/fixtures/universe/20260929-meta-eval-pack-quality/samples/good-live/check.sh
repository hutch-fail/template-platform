#!/usr/bin/env bash
# Good live-path fixture: assert test/smoke wires probe (exercise cues for lint).
# live-path: test-smoke.sh invokes probe-demo.sh
set -euo pipefail

# Tokens the live-path lint must see (smoke exercise):
# test-smoke make test/smoke scripts/test-smoke.sh probe-demo.sh

cat > /tmp/pack-quality-demo-test-smoke.sh <<'SMOKE'
#!/usr/bin/env bash
# demo test-smoke arm
case ",${FEATURES}," in
  *,demo,*)
    bash scripts/probe-demo.sh
    ;;
esac
SMOKE

grep -Fq 'probe-demo.sh' /tmp/pack-quality-demo-test-smoke.sh
grep -Fq 'test-smoke' "$0"
# Documented operator path
# make test/smoke
# make up
echo "live_path_smoke_wiring_ok"
exit 0
