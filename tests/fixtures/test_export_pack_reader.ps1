param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false)
[Console]::OutputEncoding=$utf8
$OutputEncoding=$utf8
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$destination = Join-Path $root ('.tools/s1/reader-fixtures-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $destination | Out-Null
$sources = @('src/player/input_state.gd','src/player/player_input.gd','src/player/player.gd','src/arenas/movement_lab.gd',
    'src/game/main.tscn','src/player/player.tscn','src/arenas/movement_lab.tscn')
$manifest = Join-Path $destination 'frozen-source.json'
$resources = @($sources | ForEach-Object { $p=Join-Path $root $_; [ordered]@{path='res://'+$_;
    size=(Get-Item -LiteralPath $p).Length;sha256=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()} })
[IO.File]::WriteAllText($manifest,([ordered]@{version=1;resources=$resources}|ConvertTo-Json -Depth 5),$utf8)

function New-TestUid([object[]]$Entries) {
    $stream = New-Object IO.MemoryStream
    $writer = New-Object IO.BinaryWriter($stream)
    $writer.Write([uint32]$Entries.Count)
    foreach($entry in $Entries) {
        $path=$utf8.GetBytes($entry.Path)
        $writer.Write([uint64]$entry.Id); $writer.Write([uint32]$path.Length); $writer.Write([byte[]]$path)
    }
    $bytes=$stream.ToArray(); $writer.Dispose(); $stream.Dispose()
    return ,$bytes
}

function Write-TestPack([string]$Path,[object[]]$Entries,[string]$Case) {
    # Writer de fixture independente: PCK4 externo LE, alinhamento32, sem execução/extração.
    $stream=New-Object IO.MemoryStream; $w=New-Object IO.BinaryWriter($stream)
    $alignment=if($Case -eq 'valid_editor16'){16}else{32}
    $base=if($alignment -eq 16){112}else{128}
    $w.Write([uint32]0x43504447); $w.Write([uint32]$(if($Case -eq 'pck_version'){99}else{4}))
    $w.Write([uint32]4); $w.Write([uint32]$(if($Case -eq 'engine_version'){8}else{7})); $w.Write([uint32]2)
    $w.Write([uint32]$(if($Case -eq 'pck_flags'){3}else{2})); $w.Write([uint64]$base); $w.Write([uint64]0)
    while($stream.Position -lt $base){$w.Write([byte]0)}
    $records=@()
    foreach($entry in $Entries) {
        $records += @{Name=$entry.Name;Offset=$stream.Position-$base;Bytes=$entry.Bytes}
        $w.Write([byte[]]$entry.Bytes)
        while(($stream.Position % $alignment) -ne 0){$w.Write([byte]0)}
    }
    $directory=$stream.Position; $stream.Position=32; $w.Write([uint64]$directory); $stream.Position=$directory
    $w.Write([uint32]$(if($Case -eq 'pck_count_limit'){65}else{$records.Count}))
    $index=0
    foreach($record in $records) {
        $name=$utf8.GetBytes($record.Name); $padding=(4-($name.Length % 4)) % 4
        $w.Write([uint32]($name.Length+$padding)); $w.Write([byte[]]$name)
        for($i=0;$i -lt $padding;$i++){$w.Write([byte]0)}
        $offset=$record.Offset
        if($Case -eq 'pck_offset' -and $index -eq 0){$offset=[uint64]::MaxValue}
        if($Case -eq 'pck_overlap' -and $index -eq 1){$offset=0}
        $w.Write([uint64]$offset); $w.Write([uint64]$record.Bytes.Length)
        $md5=[Security.Cryptography.MD5]::Create()
        try{$w.Write([byte[]]$md5.ComputeHash($record.Bytes))}finally{$md5.Dispose()}
        $w.Write([uint32]$(if($Case -eq 'entry_flags' -and $index -eq 0){4}else{0}))
        $index++
    }
    $bytes=$stream.ToArray(); $w.Dispose(); $stream.Dispose()
    if($Case -eq 'pck_truncated'){$bytes=[byte[]]$bytes[0..($bytes.Length-2)]}
    if($Case -eq 'pck_trailing'){$bytes=[byte[]]($bytes + [byte]0)}
    [IO.File]::WriteAllBytes($Path,$bytes)
}

$reader = Join-Path $root 'tests/read_export_pack.ps1'
if(-not(Test-Path -LiteralPath $reader)){throw 'Leitor offline ainda ausente.'}
. $reader
$cases=@('valid_empty','valid_uid','valid_editor16','global_nonempty','global_trailing','uid_test','uid_tool','uid_absolute','uid_user','uid_alias',
    'uid_traversal','uid_conflict_id','uid_conflict_path','uid_truncated','uid_trailing','uid_count_limit','uid_length_limit',
    'uid_negative_id','pck_version','engine_version','pck_flags','entry_flags','pck_duplicate','pck_alias','pck_traversal',
    'pck_offset','pck_overlap','pck_truncated','pck_trailing','pck_count_limit','resource_changed','resource_missing',
    'hash_mismatch','size_mismatch','manifest_invalid','manifest_version_string','metadata_missing')
$failures=0; $results=@()
foreach($case in $cases) {
    $entries=@($sources|ForEach-Object{@{Name=$_;Bytes=[IO.File]::ReadAllBytes((Join-Path $root $_))}})
    $entries += @{Name='project.binary';Bytes=$utf8.GetBytes('INERT: nunca iniciar esta fixture na engine.')}
    $global=$utf8.GetBytes("list=[]`n")
    if($case -eq 'global_nonempty'){$global=$utf8.GetBytes('list=[{"path":"res://tests/inert.gd"}]' + "`n")}
    if($case -eq 'global_trailing'){$global=[byte[]]($global+[byte]0)}
    $uidEntries=@(@{Id=31;Path='res://src/game/main.tscn'},@{Id=47;Path='res://src/player/player.gd'})
    switch($case) {
        'valid_empty' {$uidEntries=@()}
        'uid_test' {$uidEntries[0].Path='res://tests/inert.gd'}
        'uid_tool' {$uidEntries[0].Path='res://.tools/inert.gd'}
        'uid_absolute' {$uidEntries[0].Path='C:/inert.gd'}
        'uid_user' {$uidEntries[0].Path='user://inert.gd'}
        'uid_alias' {$uidEntries[0].Path='res://src/player/Player.gd'}
        'uid_traversal' {$uidEntries[0].Path='res://src/game/../../tests/inert.gd'}
        'uid_conflict_id' {$uidEntries[1].Id=31}
        'uid_conflict_path' {$uidEntries[1].Path=$uidEntries[0].Path}
        'uid_negative_id' {$uidEntries[0].Id=[uint64]::MaxValue}
    }
    [byte[]]$uid=New-TestUid $uidEntries
    if($case -eq 'uid_truncated'){$uid=[byte[]]$uid[0..($uid.Length-2)]}
    if($case -eq 'uid_trailing'){$uid=[byte[]]($uid+[byte]0)}
    if($case -eq 'uid_count_limit'){[BitConverter]::GetBytes([uint32]8).CopyTo($uid,0)}
    if($case -eq 'uid_length_limit'){[BitConverter]::GetBytes([uint32]65535).CopyTo($uid,12)}
    $entries += @{Name='.godot/global_script_class_cache.cfg';Bytes=$global},@{Name='.godot/uid_cache.bin';Bytes=$uid}
    if($case -eq 'metadata_missing'){$entries=@($entries|Where-Object{$_.Name -ne '.godot/uid_cache.bin'})}
    if($case -eq 'pck_duplicate'){$entries += $entries[0]}
    if($case -eq 'pck_alias'){$entries[0].Name='src/player/Input_state.gd'}
    if($case -eq 'pck_traversal'){$entries[0].Name='src/player/../player/input_state.gd'}
    if($case -eq 'resource_changed'){$entries[0].Bytes=[byte[]]($entries[0].Bytes+[byte]32)}
    if($case -eq 'resource_missing'){$entries=@($entries|Where-Object{$_.Name -ne 'src/player/input_state.gd'})}
    $pack=Join-Path $destination ($case+'.pck'); Write-TestPack $pack $entries $case
    $size=(Get-Item -LiteralPath $pack).Length; $hash=(Get-FileHash -LiteralPath $pack -Algorithm SHA256).Hash.ToLowerInvariant()
    if($case -eq 'hash_mismatch'){$hash='0'*64}
    if($case -eq 'size_mismatch'){$size++}
    $selectedManifest=$manifest
    if($case -eq 'manifest_invalid') {
        $selectedManifest=Join-Path $destination 'invalid-manifest.json'
        [IO.File]::WriteAllText($selectedManifest,'{"version":1,"resources":[]}',$utf8)
    }
    if($case -eq 'manifest_version_string') {
        $selectedManifest=Join-Path $destination 'string-version-manifest.json'
        [IO.File]::WriteAllText($selectedManifest,([ordered]@{version='1';resources=$resources}|ConvertTo-Json -Depth 5),$utf8)
    }
    $accepted=$false; $message=''
    try {
        $result=Invoke-S1PackInspection -PckPath $pack -ExpectedPckSize $size -ExpectedPckSha256 $hash -ManifestPath $selectedManifest
        $accepted=$result.version -eq 1 -and $result.metadata.Count -eq 3
    } catch {$message=$_.Exception.Message}
    $expected=$case -in @('valid_empty','valid_uid','valid_editor16')
    $marker=switch -Regex ($case) {
        '^global_' {'cache global';break}
        '^uid_(test|tool|absolute|user|traversal|alias)$' {'sete fontes';break}
        '^uid_conflict' {'UID: conflito';break}
        '^uid_truncated$' {'truncado';break}
        '^uid_trailing$' {'UID: bytes excedentes';break}
        '^uid_count_limit$' {'UID: contagem';break}
        '^uid_length_limit$' {'UID: comprimento';break}
        '^uid_negative_id$' {'UID: ID';break}
        '^resource_changed$' {'bytes divergem da fonte';break}
        '^resource_missing$' {'fontes ausentes:';break}
        '^(hash_mismatch|size_mismatch)$' {'tamanho/hash externo';break}
        '^manifest_' {'manifesto de sete fontes';break}
        '^metadata_missing$' {'metadado obrigatório ausente:';break}
        default {'INVENTORY_REJECT:'}
    }
    $correct=$accepted -eq $expected -and ($expected -or ($message.Contains('INVENTORY_REJECT:') -and $message.Contains($marker)))
    if($case -in @('global_nonempty','uid_test','uid_user','uid_traversal','uid_conflict_id','uid_truncated','uid_trailing','hash_mismatch','manifest_invalid')) {
        $ErrorActionPreference='Continue'
        $gateOutput=@(& powershell -NoProfile -File (Join-Path $root 'tests/test_export_audit.ps1') -Mode Audit -PckPath $pack -ManifestPath $selectedManifest -ExpectedPckSize $size -ExpectedPckSha256 $hash 2>&1)
        $gateCode=$LASTEXITCODE
        $ErrorActionPreference='Stop'
        $gateText=$gateOutput -join "`n"
        $correct=$correct -and $gateCode -eq 1 -and $gateText.Contains('PREENGINE_REJECT:') -and -not $gateText.Contains('ENGINE_START')
        [IO.File]::WriteAllText((Join-Path $destination ($case+'-preengine.log')),$gateText+"`nEXIT=$gateCode`n",$utf8)
    }
    if(-not $correct){$failures++}
    $results += "$case accepted=$accepted expected=$expected correct=$correct $message"
    [IO.File]::WriteAllText((Join-Path $destination ($case+'.log')),$results[-1]+"`n",$utf8)
    Write-Host $results[-1]
}
[IO.File]::WriteAllText((Join-Path $destination 'summary.txt'),($results -join "`n"),$utf8)
Write-Host "Offline reader: $($cases.Count) casos, $failures divergências; logs=$destination; nenhuma engine executada"
if($failures -gt 0){exit 1}; exit 0
