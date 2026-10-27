Set-StrictMode -Version Latest

function Resolve-GodotExecutable {
    param([string]$GodotPath)
    # O operador escolhe um executável de confiança. Esta validação não é
    # autenticação, verificação de integridade nem sandbox de executáveis.
    if ([string]::IsNullOrWhiteSpace($GodotPath) -or
        $GodotPath -match '[*?\[\]]' -or $GodotPath -match '^[\\/]{2}' -or
        ($GodotPath.Contains(':') -and $GodotPath -notmatch '^[A-Za-z]:[\\/]')) {
        throw 'GodotPath deve ser um caminho literal local, sem wildcard ou UNC.'
    }
    $provider = $null
    $drive = $null
    $localPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($GodotPath, [ref]$provider, [ref]$drive)
    if ($provider.Name -ne 'FileSystem' -or $localPath -notmatch '^[A-Za-z]:[\\/]' -or
        $localPath.Substring(2).Contains(':') -or ($drive -and $drive.DisplayRoot -match '^[\\/]{2}')) {
        throw 'GodotPath deve ser um caminho literal local, sem wildcard ou UNC.'
    }
    if ([IO.Path]::GetExtension($localPath) -ine '.exe' -or
        -not (Test-Path -LiteralPath $localPath -PathType Leaf)) {
        throw 'GodotPath deve apontar para um arquivo .exe local existente.'
    }
    $exe = (Get-Item -LiteralPath $localPath).FullName
    $versionOutput = @(& $exe --version)
    $versionCode = $LASTEXITCODE
    if ($versionCode -ne 0) {
        throw "Consulta de versao falhou (exit $versionCode). Nenhum fallback executado."
    }
    $version = ($versionOutput -join "`n").Trim()
    if ($version -cne '4.7.2.stable.official.ed1daf0bf') {
        throw "Versao incompativel: esperada 4.7.2.stable.official.ed1daf0bf; recebida '$version'."
    }
    return $exe
}
