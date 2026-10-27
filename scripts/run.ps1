param(
    [string]$GodotPath = (Join-Path $PSScriptRoot '../.tools/godot/Godot_v4.7.2-stable_win64_console.exe')
)
$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $PSScriptRoot 'godot_common.ps1')
    $exe = Resolve-GodotExecutable -GodotPath $GodotPath
    $root = Split-Path -Parent $PSScriptRoot
    & $exe --path $root
    exit $LASTEXITCODE
} catch {
    [Console]::Error.WriteLine("Execucao: $($_.Exception.Message)")
    exit 1
}
