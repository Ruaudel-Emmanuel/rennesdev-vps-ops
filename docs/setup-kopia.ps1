$ErrorActionPreference = 'Continue'
$kopia = 'C:\Users\Emmanuel\AppData\Local\Programs\KopiaUI\resources\server\kopia.exe'
$srvArgs = 'server start --address=0.0.0.0:51515 --tls-cert-file C:\Users\Emmanuel\kopia-tls\kopia-server.crt --tls-key-file C:\Users\Emmanuel\kopia-tls\kopia-server.key'

# 1. Cle publique du VPS + permissions strictes
$pub = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEi0jinZj93cFeBq2NPQH5cUwG0LaSxtc0Vky18muWZy vps-backup'
Set-Content -Path 'C:\ProgramData\ssh\administrators_authorized_keys' -Value $pub
icacls 'C:\ProgramData\ssh\administrators_authorized_keys' /inheritance:r /grant 'SYSTEM:F' /grant '*S-1-5-32-544:F'
icacls 'C:\Users\Emmanuel\kopia-tls\kopia-server.key' /inheritance:r /grant 'emmanuel:F' /grant 'SYSTEM:F' | Out-Null

# 2. Tache planifiee KopiaServer (serveur Kopia a l'ouverture de session)
$action = New-ScheduledTaskAction -Execute $kopia -Argument $srvArgs
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName 'KopiaServer' -Action $action -Trigger $trigger -RunLevel Highest -Force | Out-Null
Write-Host '== Tache KopiaServer enregistree =='

# 3. Demarrage du serveur maintenant (nouvelle fenetre : la laisser ouverte)
Start-Process -FilePath $kopia -ArgumentList $srvArgs
Write-Host '== TERMINE : serveur Kopia demarre sur 0.0.0.0:51515 =='
