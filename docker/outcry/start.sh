#!/bin/bash
set -Eeuo pipefail
export SECRET_KEY_BASE="$(cat /run/secrets/SECRET_KEY_BASE)"
export MIX_ENV=prod
/app/bin/outcry start
