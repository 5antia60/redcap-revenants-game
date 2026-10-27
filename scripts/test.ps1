param(
    [string]$GodotPath = (Join-Path $PSScriptRoot '../.tools/godot/Godot_v4.7.2-stable_win64_console.exe'),
    [switch]$SelfTestFailure
)
$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $PSScriptRoot 'godot_common.ps1')
    $exe = Resolve-GodotExecutable -GodotPath $GodotPath
    $root = Split-Path -Parent $PSScriptRoot
    $engineArguments = @('--headless', '--path', $root, '--script', 'res://tests/run_tests.gd')
    if ($SelfTestFailure) { $engineArguments += @('--', '--self-test-failure') }
    & $exe @engineArguments
    exit $LASTEXITCODE
} catch {
    [Console]::Error.WriteLine("Testes: $($_.Exception.Message)")
    exit 1
}
