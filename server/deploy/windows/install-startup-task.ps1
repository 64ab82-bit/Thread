param(
    [string]$TaskName = "ThreadApiServer",
    [int]$Port = 5001
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$publishDir = Join-Path $scriptDir "publish"
$exePath = Join-Path $publishDir "Server.exe"

if (-not (Test-Path $exePath)) {
    throw "Server.exe not found. Run publish-win.ps1 first. Expected: $exePath"
}

$arguments = "--urls http://0.0.0.0:$Port"

$action = New-ScheduledTaskAction -Execute $exePath -Argument $arguments -WorkingDirectory $publishDir
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
} catch {}

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null
Start-ScheduledTask -TaskName $TaskName

Write-Host "Scheduled task installed and started: $TaskName"
Write-Host "API endpoint: http://localhost:$Port"