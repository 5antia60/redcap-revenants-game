param(
    [string]$GodotPath = (Join-Path $PSScriptRoot '../.tools/godot/Godot_v4.7.2-stable_win64_console.exe'),
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug'
)
$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $PSScriptRoot 'godot_common.ps1')
    $exe = Resolve-GodotExecutable -GodotPath $GodotPath
    $root = Split-Path -Parent $PSScriptRoot
    $mode = $Configuration.ToLowerInvariant()
    $template = Join-Path $root ".tools/templates/4.7.2.stable/windows_${mode}_x86_64.exe"
    if (-not (Test-Path -LiteralPath $template -PathType Leaf) -or
        (Get-Item -LiteralPath $template).Length -eq 0) {
        throw "Template ausente ou vazio: $template. Preparacao local deve ser feita pelo operador; nenhum download executado."
    }
    # O template principal usa subsystem GUI: invocação direta não oferece stdout/espera
    # confiáveis no PowerShell. O launcher oficial consulta o mesmo template e aguarda sua saída.
    $templateConsole = Join-Path $root ".tools/templates/4.7.2.stable/windows_${mode}_x86_64_console.exe"
    if (-not (Test-Path -LiteralPath $templateConsole -PathType Leaf) -or
        (Get-Item -LiteralPath $templateConsole).Length -eq 0) {
        throw "Console do template ausente ou vazio: $templateConsole"
    }
    try {
        $null = Resolve-GodotExecutable -GodotPath $templateConsole
    } catch {
        throw "Template incompativel: $($_.Exception.Message)"
    }
    $directory = Join-Path $root "builds/windows-$mode"
    if (Test-Path -LiteralPath $directory) {
        # Godot também pode criar sidecars. Recusar qualquer conteúdo evita apagá-los ou substituí-los.
        if (-not (Test-Path -LiteralPath $directory -PathType Container) -or
            @(Get-ChildItem -LiteralPath $directory -Force).Count -gt 0) {
            throw "Export recusa sobrescrita: destino deve estar vazio ($directory). Preserve os artefatos antes de executar novamente."
        }
    } else {
        $null = New-Item -ItemType Directory -Path $directory
    }
    $output = Join-Path $directory 'foundation.exe'
    $pack = Join-Path $directory 'foundation.pck'
    $engineArguments = @('--headless', '--path', $root, "--export-$mode", 'Windows S0', $output)
    & $exe @engineArguments
    $code = $LASTEXITCODE
    if ($code -ne 0) { exit $code }
    foreach ($artifact in @($output, $pack)) {
        if (-not (Test-Path -LiteralPath $artifact -PathType Leaf) -or
            (Get-Item -LiteralPath $artifact).Length -eq 0) {
            throw 'Engine retornou 0 sem EXE/PCK novos e nao vazios. Export nao comprovado; saidas parciais foram preservadas.'
        }
    }
    Write-Host "Export concluido ($Configuration): $output e $pack"
    exit 0
} catch {
    [Console]::Error.WriteLine("Export: $($_.Exception.Message)")
    exit 1
}
