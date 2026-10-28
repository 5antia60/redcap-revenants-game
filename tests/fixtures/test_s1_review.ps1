param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Baseline', 'Corrected')]
    [string]$Stage
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$engine = Join-Path $root '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $engine -PathType Leaf)) { throw 'Engine fixa ausente.' }
$version = @(& $engine --version) -join "`n"
if ($LASTEXITCODE -ne 0 -or $version.Trim() -cne '4.7.2.stable.official.ed1daf0bf') {
    throw 'Engine fixa incompatível; nenhum fallback permitido.'
}
$destination = Join-Path $root ('.tools/s1/review-fixtures/' + $Stage.ToLowerInvariant() + '-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $destination | Out-Null
$files = @('project.godot', 'export_presets.cfg', 'src/game/foundation.tscn',
    'src/player/input_state.gd', 'src/player/player.gd', 'src/player/player.tscn',
    'tests/run_tests.gd', 'tests/unit/test_input_state.gd', 'tests/integration/test_player_motion.gd')
$cases = @('normal', 'missing_movement', 'missing_aim', 'runtime_subtest', 'runtime_module',
    'missing_module_run', 'multiple_ticks', 'invalid_speed')
$driverFailures = 0
$results = @()
foreach ($case in $cases) {
    $fixture = Join-Path $destination $case
    foreach ($relative in $files) {
        $target = Join-Path $fixture $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $target
    }
    $policy = Join-Path $fixture 'src/player/input_state.gd'
    $unit = Join-Path $fixture 'tests/unit/test_input_state.gd'
    if ($case -in @('missing_movement', 'missing_aim')) {
        $method = if ($case -eq 'missing_movement') { 'movement' } else { 'aim' }
        $source = [IO.File]::ReadAllText($policy)
        $needle = 'func ' + $method + '('
        if (-not $source.Contains($needle)) { throw 'Método conhecido não encontrado na fixture.' }
        [IO.File]::WriteAllText($policy, $source.Replace($needle, 'func removed_' + $method + '('), $utf8)
    }
    if ($case -in @('runtime_subtest', 'runtime_module')) {
        # Falha de execução conhecida e local, não payload recebido de terceiros.
        $method = if ($case -eq 'runtime_subtest') { '_test_movement' } else { 'run' }
        $source = [IO.File]::ReadAllText($unit)
        $pattern = '(?m)^(func ' + $method + '\([^\r\n]*\) -> (?:void|bool):)\r?$'
        $match = [regex]::Match($source, $pattern)
        if (-not $match.Success) { throw 'Subteste conhecido não encontrado na fixture.' }
        $injection = $match.Groups[1].Value + "`n`tvar absent: Variant = null`n`tabsent.get('known_fixture_runtime_error')"
        $source = $source.Remove($match.Index, $match.Length).Insert($match.Index, $injection)
        [IO.File]::WriteAllText($unit, $source, $utf8)
    }
    if ($case -eq 'missing_module_run') {
        [IO.File]::WriteAllText($unit, "extends RefCounted`n", $utf8)
    }
    if ($case -eq 'invalid_speed') {
        # Módulo isolado observa o corpo real, sem tocar o runner ou fonte vivos.
        $probe = @'
extends RefCounted

func run(tree: SceneTree, check: Callable) -> bool:
	var packed = load("res://src/player/player.tscn")
	for speed: float in [-1.0, NAN, INF, 1e100, 1001.0]:
		for move: Vector2 in [Vector2.RIGHT, Vector2.ZERO]:
			var viewport := SubViewport.new()
			viewport.world_2d = World2D.new()
			tree.root.add_child(viewport)
			var player = packed.instantiate()
			viewport.add_child(player)
			player.speed = speed
			player.apply_intent(move, Vector2.RIGHT)
			await tree.physics_frame
			await tree.process_frame
			check.call(player.velocity.is_finite() and player.velocity == Vector2.ZERO
				and player.position.is_finite() and player.position.length() < 0.001,
				"velocidade inválida deve neutralizar: speed=%s, move=%s, velocity=%s" % [speed, move, player.velocity])
			player.apply_intent(Vector2.ZERO, Vector2.ZERO)
			viewport.free()
	return true
'@
        [IO.File]::WriteAllText((Join-Path $fixture 'tests/integration/test_player_motion.gd'), $probe, $utf8)
    }
    $arguments = @('--headless', '--path', $fixture, '--script', 'res://tests/run_tests.gd')
    if ($case -eq 'multiple_ticks') { $arguments += @('--fixed-fps', '10') }
    $expected = 0
    if ($case -eq 'missing_module_run') { $expected = 1 }
    if ($Stage -eq 'Baseline' -and $case -in @('multiple_ticks', 'invalid_speed')) { $expected = 1 }
    if ($Stage -eq 'Corrected' -and $case -in @('missing_movement', 'missing_aim', 'runtime_subtest', 'runtime_module')) { $expected = 1 }
    $ErrorActionPreference = 'Continue'
    $output = @(& $engine @arguments 2>&1)
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $text = $output -join "`n"
    [IO.File]::WriteAllText((Join-Path $fixture 'result.log'), $text + "`nEXIT=$code`n", $utf8)
    $results += "$case expected=$expected actual=$code"
    Write-Host ($results[-1])
    if ($code -ne $expected) { $driverFailures++ }
    if ($Stage -eq 'Corrected' -and $case -eq 'multiple_ticks' -and
        $text -notmatch 'multiple_ticks_observed=true') {
        $driverFailures++
        Write-Host 'FAIL: condicao de multiplos ticks nao foi observada.'
    }
}
[IO.File]::WriteAllText((Join-Path $destination 'summary.txt'), ($results -join "`n") + "`n", $utf8)
Write-Host "Logs: $destination"
Write-Host "Driver: $($cases.Count) casos, $driverFailures retornos divergentes"
if ($driverFailures -gt 0) { exit 1 }
exit 0
