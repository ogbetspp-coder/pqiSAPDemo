# PQI SAP Demo

Minimal honest canonical model derived from a single SAP source string.

**Source string:** `RINVOQ 45MG 28 TABS BOTTLE CANADA`

---

## What this proves

1. A source string from an SAP-style system can be normalised into a minimal canonical PQI/FHIR R5 representation.
2. That representation can be loaded into HAPI FHIR R5 running locally in Docker.
3. A controlled update applied only to the package resource results in a new version of that resource.
4. The product resource is not versioned by a package-level change — it stays at version 1.

This is a local demo proof only. It does not represent a production system.

## What this does not prove

- Free-text parsing in general. This is one string with one explicit pattern.
- Container-closure detail. No material, closure type, foil liner, or quality standard is modelled because none is present in the source string.
- Marketing status. The string says CANADA (market token), not whether the product is authorised. `marketingStatus` is omitted entirely — the Canada market is carried in the resource ID and name.
- Route of administration. Not in the source string.
- Manufacturer or supplier. Not in the source string.
- No-change deduplication. If the same payload is PUT twice, HAPI will create a new version both times. Content-based fingerprinting to prevent spurious version bumps is future governance behaviour, not implemented here.

---

## Expected outcome

After one clean run from a fresh HAPI state:

| Check | Expected result |
|---|---|
| `/fhir/metadata` | `"fhirVersion": "5.0.0"` |
| Initial load | MPD: `201 Created`, PPD: `201 Created` |
| MPD after initial load | version 1 |
| PPD after initial load | version 1 |
| Update load (PPD only) | PPD: `200 OK` |
| MPD after update | version 1 — unchanged |
| PPD after update | version 2 |
| PPD `_history` | exactly versions 1 and 2 |

**The clean versioning proof depends on starting from a fresh HAPI state.** HAPI uses in-memory H2 storage — all data is lost when the container is removed. `docker compose down` followed by `docker compose up -d` guarantees a clean store.

---

## Resources

| Resource | ID | What it represents |
|---|---|---|
| MedicinalProductDefinition | `mpd-rinvoq-45mg` | Product anchor — stable across all package variants |
| PackagedProductDefinition | `ppd-rinvoq-45mg-28tabs-bottle-ca` | Package presentation — versions when package-level facts change |

### Deterministic ID rules

| Resource | Rule | Example |
|---|---|---|
| MPD | `mpd-{name}-{strength}` | `mpd-rinvoq-45mg` |
| PPD | `ppd-{name}-{strength}-{count}{unit}-{packaging}-{market}` | `ppd-rinvoq-45mg-28tabs-bottle-ca` |

IDs are derived from business keys in the source string. The same source string always produces the same IDs.

---

## Field justification

### Included — directly supported by source string

| Source token | Canonical field | Normalisation |
|---|---|---|
| `RINVOQ` | `MPD.name.productName` | None — literal |
| `45MG` | `MPD.name.part[StrengthPart]` | Formatted as `45 mg` |
| `TABS` | `MPD.combinedPharmaceuticalDoseForm` | TABS → Tablet (EDQM 10219000) |
| `TABS` | `MPD.name.part[DoseFormPart]` | TABS → tablets |
| `28` | `PPD.containedItemQuantity.value` | None — literal |
| `TABS` | `PPD.containedItemQuantity.unit` | TABS → tablets |
| `BOTTLE` | `PPD.packaging.type` | BOTTLE → Bottle (packaging-type 100000073497) |
| `CANADA` | `PPD.name` suffix, `PPD.id` suffix | CANADA → CA |

### Excluded — not present in source string

| Field | Reason omitted |
|---|---|
| `marketingStatus` | Market (Canada) carried in ID and name. Status (authorised/withdrawn/suspended) is not present in source string — element omitted entirely rather than using a fallback value. |
| Route of administration | Not in source string |
| Bottle material | Not in source string |
| Closure type | Not in source string |
| Foil liner | Not in source string |
| Manufacturer / supplier | Not in source string |
| Quality standards | Not in source string |
| ManufacturedItemDefinition | No item-level facts supportable from source string |

---

## What causes a new version vs what does not

| Change | Effect |
|---|---|
| A package-level field on the PPD changes | PPD gets a new version. MPD is not affected. |
| A product-level field on the MPD changes | MPD gets a new version. PPD is not affected if it did not change. |
| The same payload is PUT again with no content change | HAPI will create a new version. No-change deduplication is not implemented in this demo — see above. |

---

## How to run

Requires Docker. Run all commands from the repo root.

### Unix / Git Bash

```bash
# 1. Reset to clean state (removes all HAPI data)
docker compose down

# 2. Start fresh HAPI R5
docker compose up -d

# 3. Wait until HAPI is ready (must return 200 before loading)
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/fhir/metadata

# 4. Load initial state
./load_bundle.sh initial

# 5. Load update (PPD only — MPD is not included in update bundle)
./load_bundle.sh update
```

### PowerShell (Windows)

```powershell
# 1. Reset to clean state
docker compose down

# 2. Start fresh HAPI R5
docker compose up -d

# 3. Wait until HAPI is ready — run this until it returns 200
(Invoke-WebRequest http://localhost:8080/fhir/metadata -UseBasicParsing).StatusCode

# 4. Load initial state
.\load_bundle.ps1 initial

# 5. Load update (PPD only)
.\load_bundle.ps1 update
```

---

## Verification

Run these after completing the full load sequence above:

```
# Must show "fhirVersion": "5.0.0"
http://localhost:8080/fhir/metadata

# Must show "versionId": "1"
http://localhost:8080/fhir/MedicinalProductDefinition/mpd-rinvoq-45mg

# Must show "versionId": "2"
http://localhost:8080/fhir/PackagedProductDefinition/ppd-rinvoq-45mg-28tabs-bottle-ca

# Must show exactly versions 1 and 2
http://localhost:8080/fhir/PackagedProductDefinition/ppd-rinvoq-45mg-28tabs-bottle-ca/_history
```

---

## Files

```
compose.yaml                                              HAPI R5 service (port 8080)
load_bundle.sh                                            loader — Unix / Git Bash
load_bundle.ps1                                           loader — PowerShell
fhir/
  rinvoq-45mg-28tabs-bottle-ca.collection.json            initial canonical collection bundle
  rinvoq-45mg-28tabs-bottle-ca.transaction.json           initial HAPI transaction bundle
  rinvoq-45mg-28tabs-bottle-ca-update.collection.json     update canonical collection bundle (PPD only)
  rinvoq-45mg-28tabs-bottle-ca-update.transaction.json    update HAPI transaction bundle (PPD only)
```

---

## Runtime

- HAPI: `hapiproject/hapi:v8.6.5-1`
- FHIR: R5 (5.0.0)
- Storage: in-memory H2 (data does not persist across `docker compose down`)
- Profiles: HL7 PQI IG `MedicinalProductDefinition-drug-product-pq`, `PackagedProductDefinition-drug-pq`
