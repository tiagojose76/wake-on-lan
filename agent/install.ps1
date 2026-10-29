#Requires -RunAsAdministrator
# Registra o agente como tarefa agendada (SYSTEM, na inicialização) e libera a porta no firewall (perfil Private).
# Uso: .\install.ps1 -Token <token> [-Port 8765] [-ExePath .\agent.exe]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_-]{16,}$')][string]$Token,
    [ValidateRange(1, 65535)][int]$Port = 8765,
    [string]$ExePath = "$PSScriptRoot\agent.exe"
)
$ErrorActionPreference = 'Stop'
$exe = (Resolve-Path $ExePath).Path
$name = 'WolAgent'

# shortcut: token vai nos argumentos da tarefa (visível só para admins), trocar por arquivo com ACL se o PC for compartilhado
$action = New-ScheduledTaskAction -Execute $exe -Argument "--token $Token --port $Port"
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName $name -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port -Profile Private -Program $exe | Out-Null

Start-ScheduledTask -TaskName $name
Write-Host "Agente instalado e iniciado na porta $Port."
