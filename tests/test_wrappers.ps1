param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$powershell = Join-Path $PSHOME 'powershell.exe'
$failures = 0
$checks = 0

function Check-Wrapper {
    param([string]$Name, [string]$Script, [string[]]$Parameters, [int]$Expected, [string]$Message)
    $script:checks++
    # No Windows PowerShell, stderr nativo redirecionado vira ErrorRecord.
    # Capturá-lo não deve impedir as asserções de mensagem e código de saída.
    $ErrorActionPreference = 'Continue'
    $output = @(& $powershell -NoProfile -NonInteractive -File (Join-Path $root "scripts/$Script.ps1") @Parameters 2>&1)
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
$generated = Join-Path $PSScriptRoot ('.generated/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $generated | Out-Null
$source = Join-Path $PSScriptRoot 'fixtures/godot_stub.cs'
& $compiler /nologo /target:exe "/out:$generated/normal.exe" $source
if ($LASTEXITCODE -ne 0) { throw 'Falha na compilacao da fixture local.' }
foreach ($mode in @('exit7', 'wrong_version', 'extra_version', 'version_exit7')) {
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
} finally {
    Set-Location -LiteralPath $oldLocation.Path
    Remove-Item Env:RR_TEST_PROJECT_ROOT
}
Write-Host "Wrappers: $checks verificacoes, $failures falhas"
if ($failures -gt 0) { exit 1 }
exit 0
