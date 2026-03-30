param(
    [ValidateSet("initial","update")]
    [string]$Mode = "initial"
)

# Resolve paths relative to this script, not cwd
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ServerBase = if ($env:FHIR_BASE_URL) { $env:FHIR_BASE_URL } else { "http://localhost:8080/fhir" }

$Bundle = switch ($Mode) {
    "initial" { Join-Path $ScriptDir "fhir\rinvoq-45mg-28tabs-bottle-ca.transaction.json" }
    "update"  { Join-Path $ScriptDir "fhir\rinvoq-45mg-28tabs-bottle-ca-update.transaction.json" }
}

Write-Host "Posting $Bundle to $ServerBase"

$body = Get-Content $Bundle -Raw -Encoding UTF8
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
