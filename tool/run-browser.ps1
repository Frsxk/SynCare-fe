$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
if ($env:SYNCARE_FLUTTER_SDK) {
    $flutterExecutable = Join-Path $env:SYNCARE_FLUTTER_SDK 'bin/flutter.bat'
} else {
    $flutterExecutable = (Get-Command flutter -ErrorAction Stop).Source
}
Push-Location $projectDirectory
try {
    & $flutterExecutable build web --no-web-resources-cdn --dart-define=API_BASE=http://127.0.0.1:3001
    if ($LASTEXITCODE -ne 0) { throw 'Flutter web build failed.' }
    node tool/serve_browser.mjs
} finally {
    Pop-Location
}
