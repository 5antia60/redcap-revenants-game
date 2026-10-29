param(
    [ValidateSet('Fixtures', 'PrepareManifest', 'Audit')][string]$Mode = 'Fixtures',
    [string]$ManifestPath,
    [string]$PckPath,
    [string]$ExpectedPckSha256,
    [long]$ExpectedPckSize
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$engine = Join-Path $root '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$sources = @('src/player/input_state.gd', 'src/player/player_input.gd', 'src/player/player.gd',
    'src/arenas/movement_lab.gd', 'src/game/main.tscn', 'src/player/player.tscn', 'src/arenas/movement_lab.tscn')
. (Join-Path $PSScriptRoot 'read_export_pack.ps1')

function Write-SourceManifest([string]$Destination) {
    # Operação explícita sobre fonte congelada/revisada, não sobre inventário do PCK.
    $full = [IO.Path]::GetFullPath($Destination)
    $boundary = [IO.Path]::GetFullPath((Join-Path $root '.tools/s1')) + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase) -or
        (Test-Path -LiteralPath $full) -or -not (Test-Path -LiteralPath (Split-Path -Parent $full) -PathType Container)) {
        throw 'Manifesto novo exige diretório existente sob .tools/s1 e destino não ocupado.'
    }
    $entries = @($sources | ForEach-Object {
        $source = Join-Path $root $_
        [ordered]@{ path = 'res://' + $_; size = (Get-Item -LiteralPath $source).Length;
            sha256 = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
    $json = [ordered]@{ version = 1; resources = $entries } | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText($full, $json, $utf8)
    Write-Host "MANIFEST_PREPARED_FROM_SOURCE: $full"
}

function Invoke-PackAudit([string]$Pack, [string]$Manifest, [string]$ExpectedHash, [long]$ExpectedSize) {
    if ($ExpectedHash -cnotmatch '^[a-f0-9]{64}$' -or -not (Test-Path -LiteralPath $Pack -PathType Leaf)) {
        return @{ Code = 1; Text = 'PREENGINE_REJECT: PCK/hash externo obrigatório.' }
    }
    try {
        $attestation = Invoke-S1PackInspection -PckPath ([IO.Path]::GetFullPath($Pack)) -ExpectedPckSize $ExpectedSize -ExpectedPckSha256 $ExpectedHash -ManifestPath ([IO.Path]::GetFullPath($Manifest))
        $attestationPath = Join-Path $root ('.tools/s1/pack-attestation-' + [guid]::NewGuid().ToString('N') + '.json')
        Write-S1NewJson $attestationPath $attestation
    } catch {
        return @{ Code = 1; Text = 'PREENGINE_REJECT: ' + $_.Exception.Message }
    }
    if ((Get-Item -LiteralPath $Pack).Length -ne $ExpectedSize -or
        (Get-FileHash -LiteralPath $Pack -Algorithm SHA256).Hash.ToLowerInvariant() -cne $ExpectedHash) {
        return @{ Code = 1; Text = 'PREENGINE_REJECT: PCK mudou após inspeção offline.' }
    }
    # ProjectSettings consome project.binary antes do auditor. Só packs locais de origem
    # conhecida são autorizados; hash não autentica origem e isto não é uma sandbox.
    $arguments = @('--headless', '--main-pack', [IO.Path]::GetFullPath($Pack), '--script',
        (Join-Path $PSScriptRoot 'audit_export.gd'), '--', '--manifest', [IO.Path]::GetFullPath($Manifest), '--pack-attestation', $attestationPath)
    $ErrorActionPreference = 'Continue'
    $output = @(& $engine @arguments 2>&1)
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    return @{ Code = $code; Text = "PREENGINE_OK: metadados semanticamente inspecionados`nENGINE_START`n" + ($output -join "`n") }
}

try {
    if ($Mode -eq 'PrepareManifest') {
        if ([string]::IsNullOrWhiteSpace($ManifestPath)) { throw 'Informe ManifestPath explicitamente.' }
        Write-SourceManifest $ManifestPath
        exit 0
    }
    if ($Mode -eq 'Audit') {
        if ([string]::IsNullOrWhiteSpace($ManifestPath)) { throw 'Informe ManifestPath externo.' }
        $result = Invoke-PackAudit $PckPath $ManifestPath $ExpectedPckSha256 $ExpectedPckSize
        Write-Output $result.Text
        exit $result.Code
    }
    $version = @(& $engine --version) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $version.Trim() -cne '4.7.2.stable.official.ed1daf0bf') { throw 'Engine fixa incompatível.' }
    $id = [guid]::NewGuid().ToString('N')
    $evidence = Join-Path $root ('.tools/s1/audit-fixtures-' + $id)
    New-Item -ItemType Directory -Path $evidence | Out-Null
    $manifest = Join-Path $evidence 'source-manifest.json'
    # Manifesto válido nasce ANTES das mutações conhecidas e nunca é regenerado por caso.
    Write-SourceManifest $manifest
    $packsRelative = '.tools/s1/pack-cases-' + $id
    $packs = Join-Path $root $packsRelative
    $build = @(& $engine --headless --path $root --script 'res://tests/fixtures/build_pack_cases.gd' -- ('res://' + $packsRelative) 2>&1)
    $buildCode = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $evidence 'build.log'), ($build -join "`n"), $utf8)
    if ($buildCode -ne 0) { throw 'Construção de fixtures falhou; consultar build.log.' }
    $failures = 0
    $cases = @(Get-ChildItem -LiteralPath $packs -Filter '*.pck' -File)
    if ($cases.Count -ne 18) { throw 'Quantidade de fixtures inesperada.' }
    foreach ($case in $cases) {
        $hash = (Get-FileHash -LiteralPath $case.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $result = Invoke-PackAudit $case.FullName $manifest $hash $case.Length
        $valid = $case.BaseName -eq 'valid'
        $expected = if ($valid) { 0 } else { 1 }
        $phase = if ($valid) { $result.Text.Contains('RESOURCE_LOAD_BEGIN') } else {
            $result.Text.Contains('INVENTORY_REJECT') -and -not $result.Text.Contains('RESOURCE_LOAD_BEGIN') -and -not $result.Text.Contains('ENGINE_START') }
        if ($result.Code -ne $expected -or -not $phase) { $failures++ }
        [IO.File]::WriteAllText((Join-Path $evidence ($case.BaseName + '.log')), $result.Text + "`nEXIT=$($result.Code)`n", $utf8)
        Write-Host "$($case.BaseName) expected=$expected actual=$($result.Code) phase=$phase"
    }
    $validPack = Join-Path $packs 'valid.pck'
    $validHash = (Get-FileHash -LiteralPath $validPack -Algorithm SHA256).Hash.ToLowerInvariant()
    $validSize = (Get-Item -LiteralPath $validPack).Length
    $changedPack = Join-Path $evidence 'changed-after-hash.pck'
    Copy-Item -LiteralPath $validPack -Destination $changedPack
    $stream = [IO.File]::Open($changedPack, [IO.FileMode]::Append, [IO.FileAccess]::Write)
    try { $stream.WriteByte(0) } finally { $stream.Dispose() }
    $invalid = Join-Path $evidence 'invalid-manifest.json'
    [IO.File]::WriteAllText($invalid, '{"version":1,"resources":[]}', $utf8)
    foreach ($case in @('missing_manifest', 'invalid_manifest', 'changed_pack_hash')) {
        $selectedManifest = if ($case -eq 'missing_manifest') { Join-Path $evidence 'absent.json' } elseif ($case -eq 'invalid_manifest') { $invalid } else { $manifest }
        $selectedPack = if ($case -eq 'changed_pack_hash') { $changedPack } else { $validPack }
        $result = Invoke-PackAudit $selectedPack $selectedManifest $validHash $validSize
        $phase = if ($case -eq 'changed_pack_hash') { $result.Text.Contains('PREENGINE_REJECT') } else {
            $result.Text.Contains('INVENTORY_REJECT') -and -not $result.Text.Contains('RESOURCE_LOAD_BEGIN') -and -not $result.Text.Contains('ENGINE_START') }
        if ($result.Code -ne 1 -or -not $phase) { $failures++ }
        [IO.File]::WriteAllText((Join-Path $evidence ($case + '.log')), $result.Text + "`nEXIT=$($result.Code)`n", $utf8)
        Write-Host "$case expected=1 actual=$($result.Code) phase=$phase"
    }
    Write-Host "Audit fixtures: 21 casos, $failures divergências; logs=$evidence"
    if ($failures -gt 0) { exit 1 }
    exit 0
} catch {
    [Console]::Error.WriteLine("Audit driver: $($_.Exception.Message)")
    exit 1
}
