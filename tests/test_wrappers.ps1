param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$powershell = Join-Path $PSHOME 'powershell.exe'
$failures = 0
$checks = 0

function Check-Wrapper {
    param([string]$Name, [string]$Script, [string[]]$Parameters, [int]$Expected, [string]$Message, [string]$ProjectRoot = $root)
    $script:checks++
    # No Windows PowerShell, stderr nativo redirecionado vira ErrorRecord.
    # Capturá-lo não deve impedir as asserções de mensagem e código de saída.
    $ErrorActionPreference = 'Continue'
    $output = @(& $powershell -NoProfile -NonInteractive -File (Join-Path $ProjectRoot "scripts/$Script.ps1") @Parameters 2>&1)
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $text = $output -join "`n"
    if ($code -ne $Expected -or $text -notlike "*$Message*") {
        $script:failures++
        Write-Host "FAIL: $Name (esperado=$Expected, recebido=$code): $text"
    } else {
        Write-Host "PASS: $Name (exit=$code)"
    }
}

# Não se consulta rede nem se instala compilador: exige o .NET Framework do host.
$compiler = Join-Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'csc.exe'
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
    throw 'Compilador .NET local indisponivel; testes de processo bloqueados.'
}
$generated = Join-Path $PSScriptRoot ('.generated/literal & ' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $generated | Out-Null
$source = Join-Path $PSScriptRoot 'fixtures/godot_stub.cs'
& $compiler /nologo /target:exe "/out:$generated/normal.exe" $source
if ($LASTEXITCODE -ne 0) { throw 'Falha na compilacao da fixture local.' }
foreach ($mode in @('exit7', 'wrong_version', 'extra_version', 'version_exit7', 'no_artifacts', 'exe_only', 'empty_exe', 'empty_pck')) {
    Copy-Item -LiteralPath "$generated/normal.exe" -Destination "$generated/$mode.exe"
}
Set-Content -LiteralPath "$generated/not_engine.ps1" -Value "throw 'Esta fixture nao deve executar'" -Encoding ASCII
$env:RR_TEST_PROJECT_ROOT = $root
$oldLocation = Get-Location
try {
    # Um cwd diferente detecta wrappers que dependam de . em vez de PSScriptRoot.
    Set-Location -LiteralPath $generated
    foreach ($wrapper in @('import', 'test', 'run')) {
        Check-Wrapper "$wrapper aceita exe local e argumentos literais" $wrapper @('-GodotPath', "$generated/normal.exe") 0 'argumentos literais corretos'
        Check-Wrapper "$wrapper preserva exit 7" $wrapper @('-GodotPath', "$generated/exit7.exe") 7 'argumentos literais corretos'
        Check-Wrapper "$wrapper rejeita ausente" $wrapper @('-GodotPath', "$generated/missing.exe") 1 'arquivo .exe local existente'
        Check-Wrapper "$wrapper rejeita diretorio" $wrapper @('-GodotPath', $generated) 1 'arquivo .exe local existente'
        Check-Wrapper "$wrapper rejeita script" $wrapper @('-GodotPath', "$generated/not_engine.ps1") 1 'arquivo .exe local existente'
        Check-Wrapper "$wrapper rejeita wildcard" $wrapper @('-GodotPath', "$generated/*.exe") 1 'literal local'
        Check-Wrapper "$wrapper rejeita UNC" $wrapper @('-GodotPath', '\\invalid.example\share\godot.exe') 1 'literal local'
        Check-Wrapper "$wrapper rejeita UNC com barras" $wrapper @('-GodotPath', '//invalid.example/share/godot.exe') 1 'literal local'
        Check-Wrapper "$wrapper rejeita versao diferente" $wrapper @('-GodotPath', "$generated/wrong_version.exe") 1 'Versao incompativel'
        Check-Wrapper "$wrapper rejeita prefixo de versao" $wrapper @('-GodotPath', "$generated/extra_version.exe") 1 'Versao incompativel'
        Check-Wrapper "$wrapper rejeita consulta de versao que falhou" $wrapper @('-GodotPath', "$generated/version_exit7.exe") 1 'Consulta de versao falhou (exit 7)'
        Check-Wrapper "$wrapper rejeita vazio explicito" $wrapper @('-GodotPath', ' ') 1 'literal local'
    }
    Check-Wrapper 'test repassa falha deliberada' 'test' @('-GodotPath', "$generated/normal.exe", '-SelfTestFailure') 1 'argumentos literais corretos'

    # O wrapper real roda em cópias mínimas. Templates e builds da raiz nunca são tocados.
    foreach ($case in @('debug', 'release', 'exit7', 'no_artifacts', 'exe_only', 'empty_exe', 'empty_pck',
        'missing_engine', 'wrong_engine', 'missing_template', 'wrong_template', 'empty_template', 'missing_console', 'empty_console',
        'existing_exe', 'existing_pck', 'existing_sidecar', 'wildcard', 'unc', 'blank', 'invalid_configuration')) {
        $fixture = Join-Path $generated ("export project & literal/$case")
        $scripts = Join-Path $fixture 'scripts'
        $templates = Join-Path $fixture '.tools/templates/4.7.2.stable'
        New-Item -ItemType Directory -Path $scripts, $templates | Out-Null
        foreach ($file in @('godot_common.ps1', 'export.ps1')) {
            $inputFile = Join-Path $root "scripts/$file"
            if (Test-Path -LiteralPath $inputFile) { Copy-Item -LiteralPath $inputFile -Destination $scripts }
        }
        if (Test-Path -LiteralPath (Join-Path $root 'export_presets.cfg')) {
            Copy-Item -LiteralPath (Join-Path $root 'export_presets.cfg') -Destination $fixture
        }
        foreach ($mode in @('debug', 'release')) {
            Copy-Item -LiteralPath "$generated/normal.exe" -Destination "$templates/windows_${mode}_x86_64.exe"
            Copy-Item -LiteralPath "$generated/normal.exe" -Destination "$templates/windows_${mode}_x86_64_console.exe"
        }
        $engine = "$generated/normal.exe"
        $expected = 1
        $message = ''
        $configuration = 'Debug'
        switch ($case) {
            'debug' { $expected = 0; $message = 'Export concluido' }
            'release' { $expected = 0; $message = 'Export concluido'; $configuration = 'Release' }
            'exit7' { $engine = "$generated/exit7.exe"; $expected = 7; $message = 'argumentos literais corretos' }
            'no_artifacts' { $engine = "$generated/no_artifacts.exe"; $message = 'EXE/PCK novos e nao vazios' }
            'exe_only' { $engine = "$generated/exe_only.exe"; $message = 'EXE/PCK novos e nao vazios' }
            'empty_exe' { $engine = "$generated/empty_exe.exe"; $message = 'EXE/PCK novos e nao vazios' }
            'empty_pck' { $engine = "$generated/empty_pck.exe"; $message = 'EXE/PCK novos e nao vazios' }
            'missing_engine' { $engine = "$generated/missing.exe"; $message = 'arquivo .exe local existente' }
            'wrong_engine' { $engine = "$generated/wrong_version.exe"; $message = 'Versao incompativel' }
            'missing_template' { Remove-Item -LiteralPath "$templates/windows_debug_x86_64.exe"; $message = 'Template ausente ou vazio' }
            'wrong_template' {
                # O launcher de teste representa a versão anunciada pelo template selecionado.
                $env:RR_TEST_TEMPLATE_WRONG = '1'
                $message = 'Template incompativel'
            }
            'empty_template' { Set-Content -LiteralPath "$templates/windows_debug_x86_64.exe" -Value '' -NoNewline; $message = 'Template ausente ou vazio' }
            'missing_console' { Remove-Item -LiteralPath "$templates/windows_debug_x86_64_console.exe"; $message = 'Console do template ausente ou vazio' }
            'empty_console' { Set-Content -LiteralPath "$templates/windows_debug_x86_64_console.exe" -Value '' -NoNewline; $message = 'Console do template ausente ou vazio' }
            'wildcard' { $engine = "$generated/*.exe"; $message = 'literal local' }
            'unc' { $engine = '\\invalid.example\share\godot.exe'; $message = 'literal local' }
            'blank' { $engine = ' '; $message = 'literal local' }
            'invalid_configuration' { $configuration = 'Other'; $message = 'ValidateSet' }
        }
        $outputDir = Join-Path $fixture 'builds/windows-debug'
        $existing = $null
        if ($case -like 'existing_*') {
            New-Item -ItemType Directory -Path $outputDir | Out-Null
            $name = switch ($case) { 'existing_exe' { 'foundation.exe' } 'existing_pck' { 'foundation.pck' } 'existing_sidecar' { 'foundation.console.exe' } }
            $existing = Join-Path $outputDir $name
            Set-Content -LiteralPath $existing -Value 'nao sobrescrever' -NoNewline
            $message = 'recusa sobrescrita'
        }
        $env:RR_TEST_PROJECT_ROOT = $fixture
        $parameters = @('-GodotPath', $engine)
        if ($case -ne 'debug') { $parameters += @('-Configuration', $configuration) }
        Check-Wrapper "export $case" 'export' $parameters $expected $message $fixture
        Remove-Item Env:RR_TEST_TEMPLATE_WRONG -ErrorAction SilentlyContinue
        if ($case -in @('debug', 'release')) {
            $script:checks++
            $folder = if ($case -eq 'release') { 'windows-release' } else { 'windows-debug' }
            $exeFile = Join-Path $fixture "builds/$folder/foundation.exe"
            $pckFile = Join-Path $fixture "builds/$folder/foundation.pck"
            if (-not (Test-Path -LiteralPath $exeFile) -or -not (Test-Path -LiteralPath $pckFile)) {
                $script:failures++; Write-Host "FAIL: export $case deve produzir ambos artefatos na fixture"
            }
        }
        if ($existing) {
            $script:checks++
            if ((Get-Content -LiteralPath $existing -Raw) -cne 'nao sobrescrever') {
                $script:failures++; Write-Host "FAIL: export alterou artefato preexistente $case"
            }
        }
    }
} finally {
    Set-Location -LiteralPath $oldLocation.Path
    Remove-Item Env:RR_TEST_PROJECT_ROOT
}
Write-Host "Wrappers: $checks verificacoes, $failures falhas"
if ($failures -gt 0) { exit 1 }
exit 0
