param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverDir = Resolve-Path (Join-Path $scriptDir "..\..")
$projectPath = Join-Path $serverDir "Server.csproj"
$publishDir = Join-Path $scriptDir "publish"

Write-Host "Publishing API..."
Write-Host "Project: $projectPath"
Write-Host "Output : $publishDir"

if (Test-Path $publishDir) {
    Remove-Item -Recurse -Force $publishDir
}

& dotnet publish $projectPath `
    -c $Configuration `
    -r $Runtime `
    --self-contained true `
    /p:PublishSingleFile=true `
    /p:PublishTrimmed=false `
    -o $publishDir

Write-Host "Done."
Write-Host "Published to: $publishDir"