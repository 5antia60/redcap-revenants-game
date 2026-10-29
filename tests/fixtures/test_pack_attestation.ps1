param([string]$PckPath,[string]$ManifestPath,[long]$ExpectedPckSize,[string]$ExpectedPckSha256)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$utf8=[Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding=$utf8
$OutputEncoding=$utf8
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$full=[IO.Path]::GetFullPath($PckPath)
if(-not $full.StartsWith((Join-Path $root '.tools/s1/pack-cases-'),[StringComparison]::OrdinalIgnoreCase) -or
    [IO.Path]::GetFileName($full) -cne 'valid.pck'){throw 'Somente fixture valid.pck inerte conhecida; builds reais proibidos neste teste.'}
. (Join-Path $root 'tests/read_export_pack.ps1')
$attestation=Invoke-S1PackInspection -PckPath $full -ExpectedPckSize $ExpectedPckSize -ExpectedPckSha256 $ExpectedPckSha256 -ManifestPath $ManifestPath
$destination=Join-Path $root ('.tools/s1/attestation-fixtures-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $destination | Out-Null
$valid=Join-Path $destination 'valid.json'
Write-S1NewJson $valid $attestation
$bad=Join-Path $destination 'changed-metadata-hash.json'
$original=$attestation.metadata[0].sha256
$attestation.metadata[0].sha256='0'*64
Write-S1NewJson $bad $attestation
$attestation.metadata[0].sha256=$original
$badGlobal=Join-Path $destination 'changed-global-cache-hash.json'
$original=$attestation.metadata[1].sha256
$attestation.metadata[1].sha256='0'*64
Write-S1NewJson $badGlobal $attestation
$attestation.metadata[1].sha256=$original
$badUid=Join-Path $destination 'changed-uid-cache-hash.json'
$attestation.metadata[2].sha256='0'*64
Write-S1NewJson $badUid $attestation
$changedSource=Join-Path $destination 'same-source-different-manifest-bytes.json'
[IO.File]::WriteAllText($changedSource,([IO.File]::ReadAllText($ManifestPath)+"`n"),$utf8)
$engine=Join-Path $root '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$failures=0
foreach($case in @('normal','changed_metadata','changed_global_cache','changed_uid_cache','changed_manifest','missing_attestation')) {
    $selected=if($case -eq 'changed_metadata'){$bad}elseif($case -eq 'changed_global_cache'){$badGlobal}elseif($case -eq 'changed_uid_cache'){$badUid}elseif($case -eq 'missing_attestation'){Join-Path $destination 'absent.json'}else{$valid}
    $source=if($case -eq 'changed_manifest'){$changedSource}else{$ManifestPath}
    # O pack desta fixture continua imutável/semanticamente aprovado; só o atestado
    # externo é alterado para provar o segundo gate, antes de ResourceLoader.
    if((Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant() -cne $ExpectedPckSha256){throw 'Fixture mudou.'}
    $ErrorActionPreference='Continue'
    $output=@(& $engine --headless --main-pack $full --script (Join-Path $root 'tests/audit_export.gd') -- --manifest $source --pack-attestation $selected 2>&1)
    $code=$LASTEXITCODE
    $ErrorActionPreference='Stop'
    $text=$output -join "`n"
    $expected=if($case -eq 'normal'){0}else{1}
    $phase=if($case -eq 'normal'){$text.Contains('RESOURCE_LOAD_BEGIN')}else{$text.Contains('INVENTORY_REJECT') -and -not $text.Contains('RESOURCE_LOAD_BEGIN')}
    if($code -ne $expected -or -not $phase){$failures++}
    [IO.File]::WriteAllText((Join-Path $destination ($case+'.log')),$text+"`nEXIT=$code`n",$utf8)
    Write-Host "$case expected=$expected actual=$code phase=$phase"
}
Write-Host "Attestation gate: 6 casos, $failures divergências; logs=$destination"
if($failures -gt 0){exit 1};exit 0
