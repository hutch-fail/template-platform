Make `check.sh` pass in this workspace without changing `check.sh` or `p2p-smoke.sh`.

The SUT is `sut.sh`. It currently prints the wrong token. Fix only `sut.sh` so it prints `FIXTURE_OK` (with a trailing newline) and exits 0.

Do not weaken, delete, skip, or rewrite the check scripts.
