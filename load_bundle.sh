#!/bin/sh
set -eu

SERVER_BASE="${FHIR_BASE_URL:-http://localhost:8080/fhir}"
MODE="${1:-initial}"

case "$MODE" in
  initial)
    BUNDLE="fhir/rinvoq-45mg-28tabs-bottle-ca.transaction.json"
    ;;
  update)
    BUNDLE="fhir/rinvoq-45mg-28tabs-bottle-ca-update.transaction.json"
    ;;
  *)
    echo "Usage: ./load_bundle.sh [initial|update]" >&2
    exit 1
    ;;
esac

echo "Posting $BUNDLE to $SERVER_BASE"
curl --fail --silent --show-error \
  -X POST "$SERVER_BASE" \
  -H "Content-Type: application/fhir+json" \
  --data-binary "@$BUNDLE"
echo

echo ""
echo "Verify:"
echo "  $SERVER_BASE/MedicinalProductDefinition/mpd-rinvoq-45mg"
echo "  $SERVER_BASE/PackagedProductDefinition/ppd-rinvoq-45mg-28tabs-bottle-ca"
echo "  $SERVER_BASE/PackagedProductDefinition/ppd-rinvoq-45mg-28tabs-bottle-ca/_history"
