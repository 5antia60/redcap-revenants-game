param(
    [Alias('PckPath')][string]$ReaderPckPath,
    [Alias('ExpectedPckSize')][long]$ReaderExpectedSize,
    [Alias('ExpectedPckSha256')][string]$ReaderExpectedSha256,
    [Alias('ManifestPath')][string]$ReaderManifestPath,
    [Alias('AttestationPath')][string]$ReaderAttestationPath,
    [Alias('ReportPath')][string]$ReaderReportPath
)
# Leitor offline limitado a Godot 4.7.2/ed1daf0bf, PCK4 externo, LE, flags2.
# Fontes: core/io/{file_access_pack.h,pck_packer.cpp,resource_uid.cpp} e
# editor/export/editor_export_platform.cpp no commit ed1daf0bf de godotengine/godot.
# Não extrai arquivos, carrega recursos, executa engine ou autentica procedência.

function Get-S1SourcePaths {
    return @('res://src/player/input_state.gd','res://src/player/player_input.gd','res://src/player/player.gd',
        'res://src/arenas/movement_lab.gd','res://src/game/main.tscn','res://src/player/player.tscn','res://src/arenas/movement_lab.tscn')
}

function Assert-S1([bool]$Condition,[string]$Message) {
    if(-not $Condition){throw ('INVENTORY_REJECT: '+$Message)}
}

function Get-S1Digest([byte[]]$Bytes,[string]$Algorithm='SHA256') {
    $hash=[Security.Cryptography.HashAlgorithm]::Create($Algorithm)
    try { return ([BitConverter]::ToString($hash.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() }
    finally { $hash.Dispose() }
}

function Read-S1Bytes([IO.BinaryReader]$Reader,[long]$Count) {
    Assert-S1 ($Count -ge 0 -and $Count -le ($Reader.BaseStream.Length-$Reader.BaseStream.Position)) 'arquivo truncado/comprimento inválido'
    return ,$Reader.ReadBytes([int]$Count)
}

function Read-S1U32([IO.BinaryReader]$Reader) {
    return [BitConverter]::ToUInt32((Read-S1Bytes $Reader 4),0)
}

function Read-S1U64([IO.BinaryReader]$Reader) {
    return [BitConverter]::ToUInt64((Read-S1Bytes $Reader 8),0)
}

function Assert-S1Zero([byte[]]$Bytes,[long]$From,[long]$To) {
    Assert-S1 ($From -ge 0 -and $To -ge $From -and $To -le $Bytes.Length -and ($To-$From) -le 64) 'intervalo/padding inválido'
    for($i=$From;$i -lt $To;$i++){Assert-S1 ($Bytes[$i] -eq 0) 'padding/reservado não zero'}
}

function Read-S1LocalBytes([string]$Path,[long]$Limit) {
    Assert-S1 (-not [string]::IsNullOrWhiteSpace($Path) -and [IO.Path]::IsPathRooted($Path) -and -not $Path.StartsWith('\\')) 'arquivo local absoluto obrigatório'
    $file=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try {
        Assert-S1 ($file.Length -gt 0 -and $file.Length -le $Limit) 'tamanho de arquivo fora do limite'
        $reader=[IO.BinaryReader]::new($file)
        try { return ,(Read-S1Bytes $reader $file.Length) } finally { $reader.Dispose() }
    } finally { $file.Dispose() }
}

function Read-S1SourceManifest([string]$Path) {
    $bytes=Read-S1LocalBytes $Path 65536
    $data=([Text.UTF8Encoding]::new($false,$true).GetString($bytes))|ConvertFrom-Json
    Assert-S1 (@($data.PSObject.Properties).Count -eq 2 -and ($data.version -is [long] -or $data.version -is [int]) -and $data.version -ceq 1 -and $data.resources -is [array] -and $data.resources.Count -eq 7) 'manifesto de sete fontes inválido'
    $map=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach($entry in $data.resources) {
        Assert-S1 (@($entry.PSObject.Properties).Count -eq 3 -and $entry.path -is [string] -and (Get-S1SourcePaths) -ccontains $entry.path) 'caminho do manifesto inválido'
        Assert-S1 (-not $map.ContainsKey($entry.path)) 'fonte duplicada no manifesto'
        Assert-S1 (($entry.size -is [long] -or $entry.size -is [int]) -and $entry.size -gt 0 -and $entry.size -le 1048576) 'tamanho de fonte inválido'
        Assert-S1 ($entry.sha256 -is [string] -and $entry.sha256 -cmatch '\A[0-9a-f]{64}\z') 'SHA256 de fonte inválido'
        $map.Add($entry.path,$entry)
    }
    return @{Map=$map;Sha256=(Get-S1Digest $bytes)}
}

function Read-S1UidCache([byte[]]$Bytes) {
    Assert-S1 ($Bytes.Length -ge 4 -and $Bytes.Length -le 2048) 'UID: tamanho inválido'
    $reader=[IO.BinaryReader]::new([IO.MemoryStream]::new($Bytes,$false))
    try {
        # Este formato não tem campo próprio de versão: é fixado pelo PCK4/engine4.7.2.
        $count=Read-S1U32 $reader
        Assert-S1 ($count -le 7) 'UID: contagem excede sete fontes'
        $ids=[Collections.Generic.HashSet[uint64]]::new()
        $paths=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $entries=@()
        for($i=0;$i -lt $count;$i++) {
            $id=Read-S1U64 $reader; $length=Read-S1U32 $reader
            Assert-S1 ($id -le [uint64][long]::MaxValue) 'UID: ID negativo/inválido'
            Assert-S1 ($length -gt 0 -and $length -le 256) 'UID: comprimento inválido'
            $path=[Text.UTF8Encoding]::new($false,$true).GetString((Read-S1Bytes $reader $length))
            Assert-S1 ((Get-S1SourcePaths) -ccontains $path) 'UID: referência não canônica ou fora das sete fontes'
            Assert-S1 ($ids.Add($id) -and $paths.Add($path)) 'UID: conflito de ID ou caminho'
            $entries += [ordered]@{id=$id.ToString();path=$path}
        }
        Assert-S1 ($reader.BaseStream.Position -eq $reader.BaseStream.Length) 'UID: bytes excedentes'
        return ,$entries
    } finally { $reader.Dispose() }
}

function Write-S1NewJson([string]$Path,[object]$Data) {
    $root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../.tools/s1'))+[IO.Path]::DirectorySeparatorChar
    $full=[IO.Path]::GetFullPath($Path)
    Assert-S1 ($full.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)) 'saída deve ficar sob .tools/s1'
    $parent=[IO.Path]::GetDirectoryName($full)
    while(($parent+[IO.Path]::DirectorySeparatorChar).StartsWith($root,[StringComparison]::OrdinalIgnoreCase)) {
        Assert-S1 ([IO.Directory]::Exists($parent)) 'diretório de saída deve existir'
        Assert-S1 (([IO.File]::GetAttributes($parent) -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'saída não permite redirecionamento de diretório'
        $parent=[IO.Path]::GetDirectoryName($parent)
    }
    $stream=[IO.File]::Open($full,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try {
        $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($Data|ConvertTo-Json -Depth 8))
        $stream.Write($bytes,0,$bytes.Length)
    } finally { $stream.Dispose() }
}

function Invoke-S1PackInspection {
    param([string]$PckPath,[long]$ExpectedPckSize,[string]$ExpectedPckSha256,[string]$ManifestPath,
        [string]$AttestationPath,[string]$ReportPath)
    $report=[ordered]@{status='REJECT';format='Godot4.7.2-ed1daf0bf/PCK4';entries=@();metadata=@();uid_entries=@();error=''}
    $reader=$null
    try {
        Assert-S1 ([BitConverter]::IsLittleEndian) 'host deve ser little-endian'
        Assert-S1 ($ExpectedPckSize -ge 108 -and $ExpectedPckSize -le 8388608 -and $ExpectedPckSha256 -cmatch '\A[0-9a-f]{64}\z') 'tamanho/hash externo obrigatório'
        $bytes=Read-S1LocalBytes $PckPath 8388608
        Assert-S1 ($bytes.Length -eq $ExpectedPckSize -and (Get-S1Digest $bytes) -ceq $ExpectedPckSha256) 'PCK diverge do tamanho/hash externo congelado'
        $manifest=Read-S1SourceManifest $ManifestPath
        $reader=[IO.BinaryReader]::new([IO.MemoryStream]::new($bytes,$false))
        Assert-S1 ((Read-S1U32 $reader) -eq 0x43504447 -and (Read-S1U32 $reader) -eq 4) 'somente PCK4 externo GDPC'
        Assert-S1 ((Read-S1U32 $reader) -eq 4 -and (Read-S1U32 $reader) -eq 7 -and (Read-S1U32 $reader) -eq 2) 'engine do PCK deve ser4.7.2'
        Assert-S1 ((Read-S1U32 $reader) -eq 2) 'flags: somente filebase relativo, sem criptografia/bundle/delta'
        $fileBase=Read-S1U64 $reader; $directory=Read-S1U64 $reader
        # Exportador usa PCK_PADDING16; PCKPacker usa alinhamento32 por padrão.
        $alignment=if($fileBase -eq 112){16}else{32}
        $report.header=[ordered]@{file_base=$fileBase;directory=$directory;alignment=$alignment}
        Assert-S1 ($fileBase -in @(112,128) -and $directory -ge $fileBase -and $directory -le ($bytes.Length-4) -and ($directory % $alignment) -eq 0) 'offsets do header inválidos'
        Assert-S1Zero $bytes 40 104; Assert-S1Zero $bytes 104 ([long]$fileBase)
        $reader.BaseStream.Position=[long]$directory
        $count=Read-S1U32 $reader
        Assert-S1 ($count -ge 1 -and $count -le 64) 'contagem de arquivos fora do limite'
        $records=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
        $names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $metadataPaths=@('res://project.binary','res://.godot/global_script_class_cache.cfg','res://.godot/uid_cache.bin')
        for($i=0;$i -lt $count;$i++) {
            $length=Read-S1U32 $reader
            Assert-S1 ($length -ge 4 -and $length -le 260 -and ($length % 4) -eq 0) 'comprimento do caminho PCK inválido'
            $nameBytes=Read-S1Bytes $reader $length
            $end=$nameBytes.Length
            while($end -gt 0 -and $nameBytes[$end-1] -eq 0){$end--}
            Assert-S1 ($end -gt 0 -and ($length-$end) -le 3) 'padding de caminho inválido'
            $relative=[Text.UTF8Encoding]::new($false,$true).GetString($nameBytes,0,$end)
            Assert-S1 ($relative.IndexOf([char]0) -lt 0 -and $names.Add($relative)) 'caminho duplicado/alias/NUL'
            $path='res://'+$relative
            Assert-S1 (((Get-S1SourcePaths)+$metadataPaths) -ccontains $path) ('caminho não canônico/fora da allowlist: '+$relative)
            $offset=Read-S1U64 $reader; $size=Read-S1U64 $reader
            $md5=Read-S1Bytes $reader 16
            Assert-S1 ((Read-S1U32 $reader) -eq 0) 'flags de entrada proibidas'
            Assert-S1 ($size -gt 0 -and $size -le 1048576 -and $offset -le ($directory-$fileBase) -and $size -le ($directory-$fileBase-$offset)) 'offset/tamanho do recurso inválido'
            $start=[long]($fileBase+$offset)
            Assert-S1 (($start % $alignment) -eq 0) 'alinhamento de arquivo inválido'
            $payload=[byte[]]::new([int]$size); [Array]::Copy($bytes,$start,$payload,0,[long]$size)
            Assert-S1 ((Get-S1Digest $payload 'MD5') -ceq ([BitConverter]::ToString($md5)).Replace('-','').ToLowerInvariant()) 'MD5 de integridade do registro diverge'
            $record=@{path=$path;size=[long]$size;sha256=(Get-S1Digest $payload);start=$start;bytes=$payload}
            $records.Add($path,$record)
            $report.entries += [ordered]@{path=$path;size=[long]$size;sha256=$record.sha256;offset=$start}
        }
        Assert-S1 ($reader.BaseStream.Position -eq $bytes.Length) 'PCK: bytes excedentes após diretório'
        $previous=[long]$fileBase
        foreach($record in @($records.Values|Sort-Object {[long]$_.start})) {
            Assert-S1 ($record.start -ge $previous -and ($record.start-$previous) -le ($alignment-1)) 'sobreposição/lacuna de arquivos'
            Assert-S1Zero $bytes $previous $record.start
            $previous=$record.start+$record.size
        }
        Assert-S1 (($directory-$previous) -ge 0 -and ($directory-$previous) -le ($alignment-1)) 'padding final inválido'
        Assert-S1Zero $bytes $previous ([long]$directory)
        $metadata=@()
        foreach($path in $metadataPaths) {
            if(-not $records.ContainsKey($path)){continue}
            $record=$records[$path]
            $metadata += [ordered]@{path=$path;size=$record.size;sha256=$record.sha256}
            if($path -ne 'res://project.binary') {
                $report.metadata += [ordered]@{path=$path;size=$record.size;sha256=$record.sha256;hex=([BitConverter]::ToString($record.bytes)).Replace('-','').ToLowerInvariant()}
            }
        }
        if($records.ContainsKey('res://.godot/global_script_class_cache.cfg')) {
            Assert-S1 (([BitConverter]::ToString($records['res://.godot/global_script_class_cache.cfg'].bytes)) -ceq '6C-69-73-74-3D-5B-5D-0A') 'cache global deve ser exatamente list=[] LF, sem classes/bytes extras'
        }
        if($records.ContainsKey('res://.godot/uid_cache.bin')) {
            $report.uid_entries=Read-S1UidCache $records['res://.godot/uid_cache.bin'].bytes
            foreach($entry in $report.uid_entries){Assert-S1 ($records.ContainsKey($entry.path)) 'UID referencia fonte ausente do PCK'}
        }
        $missing=@()
        foreach($path in (Get-S1SourcePaths)) {
            if(-not $records.ContainsKey($path)){$missing += $path;continue}
            $record=$records[$path]; $expected=$manifest.Map[$path]
            Assert-S1 ($record.size -eq $expected.size -and $record.sha256 -ceq $expected.sha256) ('bytes divergem da fonte revisada: '+$path)
        }
        Assert-S1 ($missing.Count -eq 0) ('fontes ausentes: '+($missing -join ','))
        Assert-S1 ($records.ContainsKey('res://project.binary')) 'project.binary obrigatório'
        foreach($path in $metadataPaths){Assert-S1 ($records.ContainsKey($path)) ('metadado obrigatório ausente: '+$path)}
        $attestation=[ordered]@{version=1;engine='4.7.2.stable.official.ed1daf0bf';pck_format=4;pck_size=$ExpectedPckSize;
            pck_sha256=$ExpectedPckSha256;source_manifest_sha256=$manifest.Sha256;metadata=@($metadata)}
        $report.status='PASS'
        if(-not [string]::IsNullOrWhiteSpace($ReportPath)){Write-S1NewJson $ReportPath $report}
        if(-not [string]::IsNullOrWhiteSpace($AttestationPath)){Write-S1NewJson $AttestationPath $attestation}
        return $attestation
    } catch {
        $report.error=$_.Exception.Message
        if(-not [string]::IsNullOrWhiteSpace($ReportPath)){Write-S1NewJson $ReportPath $report}
        throw ('INVENTORY_REJECT: '+$_.Exception.Message)
    } finally {if($null -ne $reader){$reader.Dispose()}}
}

if($MyInvocation.InvocationName -ne '.') {
    Set-StrictMode -Version Latest
    $ErrorActionPreference='Stop'
    [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
    try {
        $result=Invoke-S1PackInspection -PckPath $ReaderPckPath -ExpectedPckSize $ReaderExpectedSize -ExpectedPckSha256 $ReaderExpectedSha256 -ManifestPath $ReaderManifestPath -AttestationPath $ReaderAttestationPath -ReportPath $ReaderReportPath
        Write-Output ('OFFLINE_OK: PCK4/4.7.2; sete fontes; metadados semanticamente validados; bytes='+$result.pck_size)
        exit 0
    } catch { [Console]::Error.WriteLine('PREENGINE_REJECT: '+$_.Exception.Message); exit 1 }
}
