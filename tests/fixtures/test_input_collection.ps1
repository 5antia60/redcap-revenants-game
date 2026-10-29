param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$engine = Join-Path $root '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$version = @(& $engine --version) -join "`n"
if ($LASTEXITCODE -ne 0 -or $version.Trim() -cne '4.7.2.stable.official.ed1daf0bf') { throw 'Engine fixa incompatível.' }
$destination = Join-Path $root ('.tools/s1/collection-mutations-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $destination | Out-Null
$files = @('project.godot', 'src/game/main.tscn', 'src/arenas/movement_lab.tscn', 'src/arenas/movement_lab.gd',
    'src/player/player.tscn', 'src/player/player.gd', 'src/player/player_input.gd', 'src/player/input_state.gd',
    'tests/fixtures/test_player_input_collection.gd', 'tests/fixtures/run_input_collection.gd')
$cases = @('normal', 'no_initial_focus', 'no_enumeration', 'wrong_axis', 'wrong_device', 'held_key_false')
$results = @()
$failures = 0
function Replace-One([string]$Source, [string]$Old, [string]$New) {
    if ([regex]::Matches($Source, [regex]::Escape($Old)).Count -ne 1) { throw 'Âncora da mutação não é única.' }
    return $Source.Replace($Old, $New)
}
foreach ($case in $cases) {
    $fixture = Join-Path $destination $case
    foreach ($relative in $files) {
        $target = Join-Path $fixture $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $target
    }
    $adapter = Join-Path $fixture 'src/player/player_input.gd'
    $source = [IO.File]::ReadAllText($adapter).Replace("`r`n", "`n")
    $marker = 'enumeração e quatro eixos do ID37'
    switch ($case) {
        'no_initial_focus' {
            $source = Replace-One $source 'set_focus_active(_read_window_has_focus())' '# Consulta inicial removida na cópia isolada.'
            $marker = 'inicialização consulta Window'
        }
        'no_enumeration' {
            $old = "func _physics_process(_delta: float) -> void:`n`tfor device: int in _read_connected_joypads():"
            $new = "func _physics_process(_delta: float) -> void:`n`tfor device: int in PackedInt32Array():"
            $source = Replace-One $source $old $new
        }
        'wrong_axis' {
            $source = Replace-One $source '_read_joy_axis(device, JOY_AXIS_RIGHT_Y)' '_read_joy_axis(device, JOY_AXIS_LEFT_Y)'
        }
        'wrong_device' {
            $source = Replace-One $source '_read_joy_axis(device, JOY_AXIS_LEFT_X)' '_read_joy_axis(0, JOY_AXIS_LEFT_X)'
        }
        'held_key_false' {
            $source = Replace-One $source 'return Input.is_physical_key_pressed(key)' 'return false'
            $marker = 'consulta global de tecla retida bloqueia'
        }
    }
    if ($case -ne 'normal') { [IO.File]::WriteAllText($adapter, $source, $utf8) }
    $ErrorActionPreference = 'Continue'
    $output = @(& $engine --headless --path $fixture --script 'res://tests/fixtures/run_input_collection.gd' 2>&1)
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $text = $output -join "`n"
    $expected = if ($case -eq 'normal') { 0 } else { 1 }
    $behavior = $text.Contains('Input collection:') -and $text -notmatch 'SCRIPT ERROR|Parse Error|WATCHDOG'
    if ($case -ne 'normal') { $behavior = $behavior -and $text.Contains('FAIL: coleta:') -and $text.Contains($marker) }
    if ($code -ne $expected -or -not $behavior) { $failures++ }
    $results += "$case expected=$expected actual=$code behavioral=$behavior"
    [IO.File]::WriteAllText((Join-Path $fixture 'result.log'), $text + "`nEXIT=$code`n", $utf8)
    Write-Host $results[-1]
}
[IO.File]::WriteAllText((Join-Path $destination 'summary.txt'), ($results -join "`n") + "`n", $utf8)
Write-Host "Collection mutations: 6 casos, $failures divergências; logs=$destination"
if ($failures -gt 0) { exit 1 }
exit 0
