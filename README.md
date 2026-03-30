# PQI SAP Demo

Minimal honest canonical model derived from a single SAP source string.

**Source string:** `RINVOQ 45MG 28 TABS BOTTLE CANADA`

---

## What this proves

1. A source string from an SAP-style system can be normalised into a canonical PQI/FHIR R5 representation.
2. That representation can be loaded into HAPI FHIR R5 running in Docker.
3. A controlled update applied only to the package resource results in a new version of that resource.
4. The product resource is not versioned by a package-level change — it stays at version 1.

## What this does not prove

- Free-text parsing in general. This is one string with one pattern.
- Container-closure detail. No material, closure type, foil liner, or quality standard is modelled because none is present in the source string.
- Marketing status. The string says CANADA (market), not whether the product is authorised, suspended, or withdrawn. That field is omitted entirely.
- Route of administration. Not in the source string.
- Manufacturer or supplier. Not in the source string.

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

IDs are derived from business keys in the source string. The same string always produces the same IDs.

---

## Field justification

### Included — directly supported by source string

| Source token | Canonical field | Normalisation applied |
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
| Route of administration | Not in source string |
| `marketingStatus` | Market (Canada) is carried in the ID and name. Status (authorised/withdrawn) is unknown from the source — the entire element is omitted rather than using a fallback value. |
| Bottle material | Not in source string |
| Closure type | Not in source string |
| Foil liner | Not in source string |
| Manufacturer / supplier | Not in source string |
| Quality standards | Not in source string |
| ManufacturedItemDefinition | No item-level facts supportable from source |

---

## What causes a new version vs what does not

| Change | Effect |
|---|---|
| A package-level field on the PPD changes | PPD gets a new version. MPD stays unchanged. |
| A product-level field on the MPD changes | MPD gets a new version. PPD is unaffected if it did not change. |
| The same payload is PUT again with no content change | HAPI will create a new version (HAPI does not perform content-based deduplication natively). In a governed engine, a fingerprint gate would prevent this PUT. |

This demo proves the first case: a PPD-only update leaves the MPD at version 1.

---

## How to run

Requires Docker.

### Unix / Git Bash

```bash
# 1. Start HAPI R5
docker compose up -d

# 2. Wait until HAPI is up (should return 200)
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/fhir/metadata

# 3. Load initial state
./load_bundle.sh initial

# 4. Load update (PPD only)
./load_bundle.sh update
```

### PowerShell (Windows)

```powershell
# 1. Start HAPI R5
docker compose up -d

# 2. Load initial state
.\load_bundle.ps1 initial

# 3. Load update (PPD only)
.\load_bundle.ps1 update
```

---

## Verification

After loading initial + update:

```
# FHIR server info — must show fhirVersion 5.0.0
http://localhost:8080/fhir/metadata

# Product anchor — must show version 1 after both loads
http://localhost:8080/fhir/MedicinalProductDefinition/mpd-rinvoq-45mg

# Package presentation — must show version 2 after update load
http://localhost:8080/fhir/PackagedProductDefinition/ppd-rinvoq-45mg-28tabs-bottle-ca

# Package version history — must show versions 1 and 2
http://localhost:8080/fhir/PackagedProductDefinition/ppd-rinvoq-45mg-28tabs-bottle-ca/_history
```

Expected result: `mpd-rinvoq-45mg` stays at version 1. `ppd-rinvoq-45mg-28tabs-bottle-ca` moves from version 1 to version 2. The update transaction bundle contains only the PPD — the MPD is not touched.

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
- Profiles: HL7 PQI IG `MedicinalProductDefinition-drug-product-pq`, `PackagedProductDefinition-drug-pq`
