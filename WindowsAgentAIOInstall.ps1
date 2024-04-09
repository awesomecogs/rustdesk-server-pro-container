$ErrorActionPreference = 'SilentlyContinue'
#Run as administrator and stays in the current directory
If (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    If ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$pwd'; & '$PSCommandPath';`"";
        Exit;
    }
}
# Replace wanipreg and keyreg with the relevant info for your install. IE wanipreg becomes your rustdesk server IP or DNS and keyreg becomes your public key.

$rustdesk_url = 'https://github.com/rustdesk/rustdesk/releases/latest'
$request = [System.Net.WebRequest]::Create($rustdesk_url)
$response = $request.GetResponse()
$realTagUrl = $response.ResponseUri.OriginalString
$rustdesk_version = $realTagUrl.split('/')[-1].Trim('v')
Write-Output("Installing Rustdesk version $rustdesk_version")

function OutputIDandPW([String]$rustdesk_id, [String]$rustdesk_pw) {
    Write-Output("######################################################")
    Write-Output("#                                                    #")
    Write-Output("# CONNECTION PARAMETERS:                             #")
    Write-Output("#                                                    #")
    Write-Output("######################################################")
    Write-Output("")
    Write-Output("  RustDesk-ID:       $rustdesk_id")
    Write-Output("  RustDesk-Password: $rustdesk_pw")
    Write-Output("")
}

If (!(Test-Path $ENV:TEMP)) {
    New-Item -ItemType Directory -Force -Path $ENV:TEMP | Out-Null
}

If (!(Test-Path "$ENV:ProgramFiles\Rustdesk\RustDesk.exe")) {

    Set-Location $ENV:TEMP

    If ([Environment]::Is64BitOperatingSystem) {
        $os_arch = "x64"
    } Else {
        $os_arch = "x32"
    }

    Invoke-WebRequest https://github.com/rustdesk/rustdesk/releases/download/$rustdesk_version/rustdesk-$rustdesk_version-windows_$os_arch.exe -Outfile rustdesk.exe

    Start-Process -FilePath "$($ENV:TEMP)\rustdesk.exe" -ArgumentList "--silent-install" -Wait

    # Set URL Handler
    New-Item -Path "HKLM:\SOFTWARE\Classes\RustDesk" | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Classes\RustDesk" -Name "(Default)" -Value "URL:RustDesk Protocol" | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\Classes\RustDesk" -Name "URL Protocol" -Type STRING | Out-Null

    New-Item -Path "HKLM:\SOFTWARE\Classes\RustDesk\DefaultIcon" | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Classes\RustDesk\DefaultIcon" -Name "(Default)" -Value "RustDesk.exe,0" | Out-Null

    New-Item -Path "HKLM:\SOFTWARE\Classes\RustDesk\shell" | Out-Null
    New-Item -Path "HKLM:\SOFTWARE\Classes\RustDesk\shell\open" | Out-Null
    New-Item -Path "HKLM:\SOFTWARE\Classes\RustDesk\shell\open\command" | Out-Null
    $rustdesklauncher = '"' + $ENV:ProgramFiles + '\RustDesk\RustDeskURLLauncher.exe" %1"'
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Classes\RustDesk\shell\open\command" -Name "(Default)" -Value $rustdesklauncher | Out-Null

    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force > null
    Install-Module ps2exe -Force > null

$urlhandler_ps1 = @"
    `$url_handler = `$args[0]
    `$rustdesk_id = `$url_handler -creplace '(?s)^.*\:',''
    Start-Process -FilePath '$ENV:ProgramFiles\RustDesk\rustdesk.exe' -ArgumentList "--connect `$rustdesk_id"
"@

    New-Item "$ENV:ProgramFiles\RustDesk\urlhandler.ps1" | Out-Null
    Set-Content "$ENV:ProgramFiles\RustDesk\urlhandler.ps1" $urlhandler_ps1 | Out-Null
    Invoke-Ps2Exe "$ENV:ProgramFiles\RustDesk\urlhandler.ps1" "$ENV:ProgramFiles\RustDesk\RustDeskURLLauncher.exe" | Out-Null

    # Cleanup Tempfiles
    Remove-Item "$ENV:ProgramFiles\RustDesk\urlhandler.ps1" | Out-Null
    Set-Location -Path $ENV:TEMP
    Remove-Item $ENV:TEMP\rustdesk -Recurse | Out-Null
    Remove-Item $ENV:TEMP\rustdesk.zip | Out-Null
}

# Write config
$RustDesk2_toml = @"
rendezvous_server = 'wanipreg'
nat_type = 1
serial = 0

[options]
custom-rendezvous-server = 'wanipreg'
key = 'keyreg'
relay-server = 'wanipreg'
api-server = 'https://wanipreg'
enable-audio = 'N'
direct-server = 'Y'
"@

If (!(Test-Path $ENV:AppData\RustDesk\config\RustDesk2.toml)) {
    New-Item $ENV:AppData\RustDesk\config\RustDesk2.toml | Out-Null
}
Set-Content $ENV:AppData\RustDesk\config\RustDesk2.toml $RustDesk2_toml | Out-Null

If (!(Test-Path $ENV:WinDir\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml)) {
    New-Item $ENV:WinDir\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml | Out-Null
}
Set-Content $ENV:WinDir\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml $RustDesk2_toml | Out-Null

$random_pass = (-join ((65..90) + (97..122) | Get-Random -Count 8 | % {[char]$_}))
Start-Process "$ENV:ProgramFiles\RustDesk\RustDesk.exe"  -argumentlist "--password $random_pass" -wait

# Get RustDesk ID
If (!("$ENV:WinDir\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml")) {
    $rustdesk_id = (Get-Content $ENV:AppData\RustDesk\config\RustDesk.toml | Where-Object { $_.Contains("id") })
    $rustdesk_id = $rustdesk_id.Split("'")[1]
    $rustdesk_pw = (Get-Content $ENV:AppData\RustDesk\config\RustDesk.toml | Where-Object { $_.Contains("password") })
    $rustdesk_pw = $rustdesk_pw.Split("'")[1]
    Write-Output("Config file found in user folder")
    OutputIDandPW $rustdesk_id $rustdesk_pw
} Else {
    $rustdesk_id = (Get-Content $ENV:WinDir\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml | Where-Object { $_.Contains("id") })
    $rustdesk_id = $rustdesk_id.Split("'")[1]
    $rustdesk_pw = (Get-Content $ENV:WinDir\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml | Where-Object { $_.Contains("password") })
    $rustdesk_pw = $rustdesk_pw.Split("'")[1]
    Write-Output "Config file found in windows service folder"
    OutputIDandPW $rustdesk_id $rustdesk_pw
}

Stop-Process -Name RustDesk -Force | Out-Null
Start-Service -Name RustDesk | Out-Null
