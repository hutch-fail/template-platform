#!/usr/bin/env bash
# Broken SUT for TB1: must not emit FIXTURE_OK until golden.patch is applied.
set -euo pipefail
printf 'WRONG_TOKEN\n'
