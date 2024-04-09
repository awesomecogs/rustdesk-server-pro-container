$ErrorActionPreference= 'silentlycontinue'

If (!(Test-Path "$ENV:ProgramFiles\Rustdesk\RustDesk.exe")) {

    $rustdesk_url = 'https://github.com/rustdesk/rustdesk/releases/latest'
    $request = [System.Net.WebRequest]::Create($rustdesk_url)
    $response = $request.GetResponse()
    $realTagUrl = $response.ResponseUri.OriginalString
    $rustdesk_version = $realTagUrl.split('/')[-1].Trim('v')
    Write-Output("Installing Rustdesk version $rustdesk_version")
    
    If (!(Test-Path $ENV:TEMP)) {
        New-Item -ItemType Directory -Force -Path $ENV:TEMP > null
    }
      
    Set-Location $ENV:TEMP
  
    If ([Environment]::Is64BitOperatingSystem) {
        $os_arch = "x64"
    } Else {
        $os_arch = "x32"
    }
  
    Invoke-WebRequest https://github.com/rustdesk/rustdesk/releases/download/$rustdesk_version/rustdesk-$rustdesk_version-windows_$os_arch.exe -Outfile rustdesk.exe
  
    Start-Process -FilePath "$($ENV:TEMP)\rustdesk.exe" -ArgumentList "--silent-install" -Wait
}
