param(
    [ValidateSet("initial","update")]
    [string]$Mode = "initial"
)

$ServerBase = $env:FHIR_BASE_URL ?? "http://localhost:8080/fhir"

$Bundle = switch ($Mode) {
    "initial" { "fhir/rinvoq-45mg-28tabs-bottle-ca.transaction.json" }
    "update"  { "fhir/rinvoq-45mg-28tabs-bottle-ca-update.transaction.json" }
}

Write-Host "Posting $Bundle to $ServerBase"

$body = Get-Content $Bundle -Raw
Invoke-RestMethod `
    -Method Post `
    -Uri $ServerBase `
    -ContentType "application/fhir+json" `
    -Body $body | ConvertTo-Json -Depth 5

Write-Host ""
Write-Host "Verify:"
Write-Host "  $ServerBase/MedicinalProductDefinition/mpd-rinvoq-45mg"
Write-Host "  $ServerBase/PackagedProductDefinition/ppd-rinvoq-45mg-28tabs-bottle-ca"
Write-Host "  $ServerBase/PackagedProductDefinition/ppd-rinvoq-45mg-28tabs-bottle-ca/_history"
