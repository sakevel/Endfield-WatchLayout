param([string]$LupaPath='', [string]$ServicesFixture='')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$args=@('-S',$root,'-B',(Join-Path $root 'build'),'-G','Visual Studio 17 2022','-A','x64',"-DZML_LUPA_PATH=$LupaPath","-DZML_SERVICES_TEST_EXE=$ServicesFixture")
& cmake @args;if($LASTEXITCODE){throw 'Configure failed'}
& cmake --build (Join-Path $root 'build') --config Release --parallel 6;if($LASTEXITCODE){throw 'Build failed'}
& ctest --test-dir (Join-Path $root 'build') -C Release --output-on-failure;if($LASTEXITCODE){throw 'Tests failed'}
