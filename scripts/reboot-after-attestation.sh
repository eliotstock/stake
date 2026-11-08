#!/usr/bin/env bash
#
# Reboot the staking machine with as little disruption to validator duties as
# possible.
#
# Waits for the validator to publish an attestation, checks the next one is far
# enough away to get through a reboot, then stops the node services and reboots.
# Shows the validator client's per-slot status while it waits.
#
# Usage: ./scripts/reboot-after-attestation.sh [--dry-run]
#
# Re-runs itself under sudo, so any password prompt comes up front, not after
# the attestation.

set -euo pipefail

VALIDATOR_INDEX=490968
BEACON_NODE=http://192.168.20.51:5052
# Stop the signer first so nothing gets signed during shutdown.
SERVICES=(lighthouse-vc lighthouse-bn mev-boost nethermind)
# Minimum time between the attestation we just made and the next one, to get
# through a reboot and catch up.
MIN_GAP_SECS=300
# Give up if no suitable attestation turns up within this long.
TIMEOUT_SECS=1800
# Wait this long after the attestation in case we're also aggregating this slot.
GRACE_SECS=8

dry_run=0
if [[ "${1:-}" == "--dry-run" ]]; then
    dry_run=1
fi

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

log() {
    printf '%s  %s\n' "$(date -u +%H:%M:%S)" "$*"
}

die() {
    log "ERROR: $*"
    exit 1
}

# Value of a numeric "name: value" field in a Lighthouse log line.
field() {
    grep -oP "$1: \"?\K[0-9]+" <<<"$2" | head -1 || true
}

# Slot of the validator's attestation duty in the given epoch, from the beacon
# node. Prints nothing on failure.
attestation_slot() {
    curl -sf --max-time 5 -X POST -H 'Content-Type: application/json' \
        -d "[\"$VALIDATOR_INDEX\"]" \
        "$BEACON_NODE/eth/v1/validator/duties/attester/$1" \
        | grep -oP '"slot":"\K[0-9]+' | head -1 || true
}

if (( dry_run )); then
    log "Dry run: won't stop services or reboot."
fi
log "Waiting for validator $VALIDATOR_INDEX's next attestation. Ctrl-C to cancel."

exec 3< <(journalctl -u lighthouse-vc -f -n 0 -o cat)
journal_pid=$!
trap 'kill "$journal_pid" 2>/dev/null || true' EXIT

deadline=$((SECONDS + TIMEOUT_SECS))
proposers=0
warned_sync_committee=0

while true; do
    if (( SECONDS >= deadline )); then
        die "No suitable attestation within ${TIMEOUT_SECS}s. Not rebooting."
    fi

    # Time out every few seconds so the deadline check above still runs if the
    # validator client goes quiet.
    IFS= read -r -t 5 -u 3 line || {
        status=$?
        if (( status > 128 )); then
            continue
        fi
        die "journalctl stopped unexpectedly."
    }

    case "$line" in
        *"Successfully published attestations"*)
            slot=$(field slot "$line")
            log "Attestation published for slot ${slot:-?}."

            if (( ${proposers:-0} > 0 )); then
                log "A block proposal is due this epoch. Waiting for the next attestation."
                continue
            fi

            if [[ -z "$slot" ]]; then
                log "Couldn't read the slot, so can't check the next duty. Going ahead anyway."
                break
            fi

            next=$(attestation_slot $(( slot / 32 + 1 )))
            if [[ -z "$next" ]]; then
                log "Couldn't get next epoch's duties from the beacon node. Going ahead anyway."
                break
            fi

            gap=$(( (next - slot) * 12 ))
            log "Next attestation is at slot $next, ${gap}s after this one."
            if (( gap < MIN_GAP_SECS )); then
                log "That's under ${MIN_GAP_SECS}s. Waiting for the next attestation."
                continue
            fi
            break
            ;;
        *"All validators active"*)
            proposers=$(field current_epoch_proposers "$line")
            log "Slot $(field slot "$line"): waiting. Block proposals this epoch: ${proposers:-0}."
            ;;
        *"sync committee"*)
            if (( ! warned_sync_committee )); then
                log "Note: the validator is in a sync committee. A reboot will miss a few sync committee messages."
                warned_sync_committee=1
            fi
            ;;
        *" WARN "*|*" ERRO"*|*" CRIT "*)
            log "lighthouse-vc: $line"
            ;;
    esac
done

log "Waiting ${GRACE_SECS}s in case we're aggregating this slot."
sleep "$GRACE_SECS"
kill "$journal_pid" 2>/dev/null || true

for service in "${SERVICES[@]}"; do
    log "Stopping $service."
    if (( ! dry_run )); then
        systemctl stop "$service" || log "Failed to stop $service. Carrying on."
    fi
done

log "Rebooting."
if (( ! dry_run )); then
    systemctl reboot
fi
