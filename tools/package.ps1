$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$package=Join-Path $root 'build/package/Release/watch-layout'
$manifest=Get-Content -LiteralPath (Join-Path $package 'zml-package.json') -Raw | ConvertFrom-Json
$files=@($manifest.files)+@('zml-package.json')
if($manifest.id -ne 'watch-layout' -or $files.Count -ne 7){throw 'Whitelist changed'}
$paths=@($files | ForEach-Object {
 if($_ -notmatch '^[a-zA-Z0-9._-]+$'){throw 'Unsafe filename'}
 $p=Join-Path $package $_
 if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Missing runtime file $_"}
 $p
})
$dist=Join-Path $root 'dist';New-Item -ItemType Directory -Force $dist | Out-Null
$zip=Join-Path $dist ('EndfieldWatchLayout-0.3.1-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.zip')
Compress-Archive -LiteralPath $paths -DestinationPath $zip
(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash+'  '+(Split-Path $zip -Leaf) | Set-Content -Encoding ascii ($zip+'.sha256')
Write-Output $zip
