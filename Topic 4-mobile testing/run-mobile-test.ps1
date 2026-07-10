param(
  [string] $InstallRoot = "D:\Android",
  [string] $AvdName = "test_device",
  [int] $BackendPort = 8080,
  [switch] $CloseEmulatorAfterTest,
  [switch] $StopBackendAfterTest,
  [switch] $ManualDemo
)

$ErrorActionPreference = "Stop"

$TopicDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $TopicDir "..")).Path
$MobileAppDir = Join-Path $TopicDir "mobile_app"
$MaestroFlow = Join-Path $TopicDir "maestro\check-valid-date.yaml"
$LogsDir = Join-Path $TopicDir "logs"
$DownloadsDir = Join-Path $InstallRoot "downloads"
$AndroidHome = Join-Path $InstallRoot "Sdk"
$AndroidAvdHome = Join-Path $InstallRoot "avd"
$AndroidEmulatorHome = Join-Path $InstallRoot ".android"
$FlutterHome = Join-Path $InstallRoot "flutter"
$MaestroHome = Join-Path $InstallRoot "maestro"
$TempDir = Join-Path $InstallRoot "temp"
$CmdlineToolsUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
$FlutterReleasesUrl = "https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json"
$BackendLog = Join-Path $LogsDir "spring-boot.log"
$BackendErrLog = Join-Path $LogsDir "spring-boot.err.log"
$EmulatorLog = Join-Path $LogsDir "emulator.log"
$EmulatorErrLog = Join-Path $LogsDir "emulator.err.log"

$BackendProcess = $null
$EmulatorProcess = $null
$StartedBackend = $false

function Write-Step {
  param([string] $Message)
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Ensure-Directory {
  param([string] $Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}

function Add-PathForSession {
  param([string] $Path)
  if ((Test-Path -LiteralPath $Path) -and (($env:Path -split ";") -notcontains $Path)) {
    $env:Path = "$Path;$env:Path"
  }
}

function Add-UserPathIfMissing {
  param([string] $Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }

  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  $parts = @()
  if ($userPath) {
    $parts = $userPath -split ";"
  }

  if ($parts -notcontains $Path) {
    $newPath = if ($userPath) { "$userPath;$Path" } else { $Path }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
  }
}

function Download-File {
  param(
    [string] $Url,
    [string] $Destination
  )

  if (Test-Path -LiteralPath $Destination) {
    return
  }

  Ensure-Directory (Split-Path -Parent $Destination)
  Write-Host "Downloading $Url"
  curl.exe -L --retry 10 --retry-delay 5 --connect-timeout 30 -o $Destination $Url
  if ($LASTEXITCODE -ne 0) {
    throw "Download failed: $Url"
  }
}

function Expand-ZipFresh {
  param(
    [string] $ZipPath,
    [string] $Destination
  )

  if (Test-Path -LiteralPath $Destination) {
    return
  }

  $parent = Split-Path -Parent $Destination
  Ensure-Directory $parent
  Expand-Archive -LiteralPath $ZipPath -DestinationPath $parent -Force
}

function Ensure-AndroidSdk {
  Write-Step "Checking Android SDK command-line tools"
  Ensure-Directory $InstallRoot
  Ensure-Directory $DownloadsDir
  Ensure-Directory $AndroidHome
  Ensure-Directory $AndroidAvdHome
  Ensure-Directory $AndroidEmulatorHome
  Ensure-Directory $TempDir

  $env:ANDROID_HOME = $AndroidHome
  $env:ANDROID_SDK_ROOT = $AndroidHome
  $env:ANDROID_AVD_HOME = $AndroidAvdHome
  $env:ANDROID_EMULATOR_HOME = $AndroidEmulatorHome
  $env:TEMP = $TempDir
  $env:TMP = $TempDir
  [Environment]::SetEnvironmentVariable("ANDROID_HOME", $AndroidHome, "User")
  [Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $AndroidHome, "User")
  [Environment]::SetEnvironmentVariable("ANDROID_AVD_HOME", $AndroidAvdHome, "User")
  [Environment]::SetEnvironmentVariable("ANDROID_EMULATOR_HOME", $AndroidEmulatorHome, "User")

  $latestToolDir = Join-Path $AndroidHome "cmdline-tools\latest"
  $sdkManager = Join-Path $latestToolDir "bin\sdkmanager.bat"

  if (-not (Test-Path -LiteralPath $sdkManager)) {
    $zipPath = Join-Path $DownloadsDir "android-commandlinetools.zip"
    $extractRoot = Join-Path $DownloadsDir "android-commandlinetools"
    Download-File -Url $CmdlineToolsUrl -Destination $zipPath
    if (Test-Path -LiteralPath $extractRoot) {
      Remove-Item -Recurse -Force -LiteralPath $extractRoot
    }
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force

    $sourceTools = Join-Path $extractRoot "cmdline-tools"
    if (-not (Test-Path -LiteralPath $sourceTools)) {
      throw "Android cmdline-tools archive did not contain cmdline-tools."
    }

    Ensure-Directory (Join-Path $AndroidHome "cmdline-tools")
    if (Test-Path -LiteralPath $latestToolDir) {
      Remove-Item -Recurse -Force -LiteralPath $latestToolDir
    }
    Move-Item -LiteralPath $sourceTools -Destination $latestToolDir
  }

  Add-PathForSession (Join-Path $AndroidHome "cmdline-tools\latest\bin")
  Add-PathForSession (Join-Path $AndroidHome "platform-tools")
  Add-PathForSession (Join-Path $AndroidHome "emulator")
  Add-UserPathIfMissing (Join-Path $AndroidHome "cmdline-tools\latest\bin")
  Add-UserPathIfMissing (Join-Path $AndroidHome "platform-tools")
  Add-UserPathIfMissing (Join-Path $AndroidHome "emulator")

  $requiredSdkFiles = @(
    (Join-Path $AndroidHome "platform-tools\adb.exe"),
    (Join-Path $AndroidHome "emulator\emulator.exe"),
    (Join-Path $AndroidHome "platforms\android-35\android.jar"),
    (Join-Path $AndroidHome "platforms\android-36\android.jar"),
    (Join-Path $AndroidHome "build-tools\35.0.0\aapt2.exe"),
    (Join-Path $AndroidHome "build-tools\36.0.0\aapt2.exe"),
    (Join-Path $AndroidHome "system-images\android-30\google_apis\x86_64\system.img")
  )

  $missingSdkFile = $requiredSdkFiles | Where-Object { -not (Test-Path -LiteralPath $_) } | Select-Object -First 1
  if ($missingSdkFile) {
    Write-Step "Installing Android SDK packages"
    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
      $licenseAnswers = 1..120 | ForEach-Object { "y" }
      $licenseAnswers | & $sdkManager `
        "platform-tools" `
        "emulator" `
        "platforms;android-35" `
        "platforms;android-36" `
        "build-tools;35.0.0" `
        "build-tools;36.0.0" `
        "system-images;android-30;google_apis;x86_64"
    } finally {
      $ErrorActionPreference = $oldErrorActionPreference
    }

    if ($LASTEXITCODE -ne 0) {
      throw "sdkmanager package install failed."
    }
  } else {
    Write-Host "Android SDK packages already installed."
  }

  if (-not (Test-Path -LiteralPath (Join-Path $AndroidHome "licenses\android-sdk-license"))) {
    Write-Step "Accepting Android SDK licenses"
    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
      $yes = 1..120 | ForEach-Object { "y" }
      $yes | & $sdkManager --licenses
    } finally {
      $ErrorActionPreference = $oldErrorActionPreference
    }
  } else {
    Write-Host "Android SDK licenses already accepted."
  }
}

function Ensure-Flutter {
  Write-Step "Checking Flutter SDK"
  $flutterBat = Join-Path $FlutterHome "bin\flutter.bat"

  if (-not (Test-Path -LiteralPath $flutterBat)) {
    Ensure-Directory $DownloadsDir
    Write-Host "Resolving latest stable Flutter SDK for Windows"
    $metadata = Invoke-RestMethod -Uri $FlutterReleasesUrl
    $stableHash = $metadata.current_release.stable
    $stableRelease = $metadata.releases | Where-Object { $_.hash -eq $stableHash } | Select-Object -First 1
    if (-not $stableRelease) {
      throw "Could not resolve latest stable Flutter release."
    }

    $archiveUrl = "https://storage.googleapis.com/flutter_infra_release/releases/$($stableRelease.archive)"
    $zipPath = Join-Path $DownloadsDir "flutter-windows-stable.zip"
    Download-File -Url $archiveUrl -Destination $zipPath

    $tempFlutterRoot = Join-Path $DownloadsDir "flutter_extract"
    if (Test-Path -LiteralPath $tempFlutterRoot) {
      Remove-Item -Recurse -Force -LiteralPath $tempFlutterRoot
    }
    Expand-Archive -LiteralPath $zipPath -DestinationPath $tempFlutterRoot -Force

    $extractedFlutter = Join-Path $tempFlutterRoot "flutter"
    if (-not (Test-Path -LiteralPath $extractedFlutter)) {
      throw "Flutter archive did not contain flutter folder."
    }

    if (Test-Path -LiteralPath $FlutterHome) {
      Remove-Item -Recurse -Force -LiteralPath $FlutterHome
    }
    Move-Item -LiteralPath $extractedFlutter -Destination $FlutterHome
  }

  Add-PathForSession (Join-Path $FlutterHome "bin")
  Add-UserPathIfMissing (Join-Path $FlutterHome "bin")

  Remove-BrokenAndroidStudioConfig
  & $flutterBat --version
  & $flutterBat config --android-sdk $AndroidHome
}

function Remove-BrokenAndroidStudioConfig {
  $googleLocal = Join-Path $env:LOCALAPPDATA "Google"
  if (-not (Test-Path -LiteralPath $googleLocal)) {
    return
  }

  Get-ChildItem -LiteralPath $googleLocal -Directory -Filter "AndroidStudio*" -ErrorAction SilentlyContinue |
    ForEach-Object {
      $homeFile = Join-Path $_.FullName ".home"
      if (-not (Test-Path -LiteralPath $homeFile)) {
        Write-Host "Removing broken Android Studio config: $($_.FullName)"
        Remove-Item -Recurse -Force -LiteralPath $_.FullName
      }
    }
}

function Ensure-Maestro {
  Write-Step "Checking Maestro CLI"
  $maestroBat = Get-MaestroExecutable

  if (-not $maestroBat) {
    Ensure-Directory $DownloadsDir
    Write-Host "Resolving latest Maestro release from GitHub"
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/mobile-dev-inc/maestro/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -eq "maestro.zip" } | Select-Object -First 1
    if (-not $asset) {
      throw "Could not find maestro.zip in latest Maestro release."
    }

    $zipPath = Join-Path $DownloadsDir "maestro.zip"
    Download-File -Url $asset.browser_download_url -Destination $zipPath

    if (Test-Path -LiteralPath $MaestroHome) {
      Remove-Item -Recurse -Force -LiteralPath $MaestroHome
    }
    Expand-Archive -LiteralPath $zipPath -DestinationPath $MaestroHome -Force
  }

  $maestroBat = Get-MaestroExecutable
  if (-not $maestroBat) {
    throw "Maestro executable was not found under $MaestroHome after extraction."
  }

  $maestroBin = Split-Path -Parent $maestroBat
  Add-PathForSession $maestroBin
  Add-UserPathIfMissing $maestroBin

  & $maestroBat --version
}

function Get-MaestroExecutable {
  $candidates = @(
    (Join-Path $MaestroHome "bin\maestro.bat"),
    (Join-Path $MaestroHome "bin\maestro.cmd"),
    (Join-Path $MaestroHome "maestro\bin\maestro.bat"),
    (Join-Path $MaestroHome "maestro\bin\maestro.cmd")
  )

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  if (Test-Path -LiteralPath $MaestroHome) {
    $found = Get-ChildItem -LiteralPath $MaestroHome -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -in @("maestro.bat", "maestro.cmd") } |
      Select-Object -First 1
    if ($found) {
      return $found.FullName
    }
  }

  return $null
}

function Ensure-NativeFlutterProject {
  Write-Step "Generating missing native Flutter folders"
  $flutterBat = Join-Path $FlutterHome "bin\flutter.bat"
  Push-Location $MobileAppDir
  try {
    if (-not (Test-Path -LiteralPath "android")) {
      & $flutterBat create --org com.example --platforms=android,ios .
      if ($LASTEXITCODE -ne 0) {
        throw "flutter create failed."
      }
    }

    if (-not (Test-Path -LiteralPath "android")) {
      throw "Flutter android folder is still missing after flutter create."
    }
  } finally {
    Pop-Location
  }

  Ensure-AndroidManifestNetworkAccess
}

function Ensure-AndroidManifestNetworkAccess {
  Write-Step "Ensuring Android Internet and cleartext HTTP access"
  $manifestPath = Join-Path $MobileAppDir "android\app\src\main\AndroidManifest.xml"
  if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "AndroidManifest.xml was not found at $manifestPath."
  }

  $manifest = Get-Content -LiteralPath $manifestPath -Raw

  if ($manifest -notmatch "android.permission.INTERNET") {
    $manifest = $manifest -replace "<manifest([^>]*)>", "<manifest`$1>`r`n    <uses-permission android:name=`"android.permission.INTERNET`" />"
  }

  if ($manifest -notmatch "usesCleartextTraffic") {
    $manifest = $manifest -replace "<application", "<application android:usesCleartextTraffic=`"true`""
  }

  Set-Content -LiteralPath $manifestPath -Value $manifest -Encoding UTF8
}

function Get-ApplicationId {
  $gradleKts = Join-Path $MobileAppDir "android\app\build.gradle.kts"
  $gradleGroovy = Join-Path $MobileAppDir "android\app\build.gradle"
  $files = @($gradleKts, $gradleGroovy) | Where-Object { Test-Path -LiteralPath $_ }

  foreach ($file in $files) {
    $content = Get-Content -LiteralPath $file -Raw
    if ($content -match 'applicationId\s*=\s*"([^"]+)"') {
      return $Matches[1]
    }
    if ($content -match 'applicationId\s+"([^"]+)"') {
      return $Matches[1]
    }
    if ($content -match 'namespace\s*=\s*"([^"]+)"') {
      return $Matches[1]
    }
    if ($content -match 'namespace\s+"([^"]+)"') {
      return $Matches[1]
    }
  }

  return "com.example.mobile_app"
}

function Ensure-Avd {
  Write-Step "Creating Android Virtual Device if needed"
  $avdManager = Join-Path $AndroidHome "cmdline-tools\latest\bin\avdmanager.bat"
  $emulator = Join-Path $AndroidHome "emulator\emulator.exe"
  Ensure-Directory $AndroidAvdHome
  Ensure-Directory $AndroidEmulatorHome
  Ensure-Directory $TempDir

  $env:ANDROID_AVD_HOME = $AndroidAvdHome
  $env:ANDROID_EMULATOR_HOME = $AndroidEmulatorHome
  $env:TEMP = $TempDir
  $env:TMP = $TempDir

  $defaultAvdHome = Join-Path $env:USERPROFILE ".android\avd"
  $oldAvdDir = Join-Path $defaultAvdHome "$AvdName.avd"
  $oldAvdIni = Join-Path $defaultAvdHome "$AvdName.ini"
  if ((Test-Path -LiteralPath $oldAvdDir) -or (Test-Path -LiteralPath $oldAvdIni)) {
    Write-Host "Removing old AVD from C: $oldAvdDir"
    Remove-Item -Recurse -Force -LiteralPath $oldAvdDir -ErrorAction SilentlyContinue
    Remove-Item -Force -LiteralPath $oldAvdIni -ErrorAction SilentlyContinue
  }

  $avds = & $emulator -list-avds
  if (($avds -split "`r?`n") -notcontains $AvdName) {
    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
      $no = "no"
      $no | & $avdManager create avd `
        --force `
        --name $AvdName `
        --package "system-images;android-30;google_apis;x86_64" `
        --device "pixel_2"
    } finally {
      $ErrorActionPreference = $oldErrorActionPreference
    }

    if ($LASTEXITCODE -ne 0) {
      throw "avdmanager failed to create AVD '$AvdName'."
    }
  }
}

function Reset-StaleEmulatorState {
  param([string] $Adb)

  $devices = & $Adb devices
  $online = $devices | Select-String -Pattern "^emulator-\d+\s+device"
  if ($online) {
    return
  }

  $offline = $devices | Select-String -Pattern "^emulator-\d+\s+offline"
  $emulatorProcesses = Get-Process emulator, qemu-system-x86_64 -ErrorAction SilentlyContinue
  if (-not $offline -and -not $emulatorProcesses) {
    return
  }

  Write-Host "Removing stale/offline emulator state before starting $AvdName."
  $emulatorProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2

  $oldErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & $Adb kill-server *> $null
  } finally {
    $ErrorActionPreference = $oldErrorActionPreference
  }

  $avdDir = Join-Path $AndroidAvdHome "$AvdName.avd"
  if (Test-Path -LiteralPath $avdDir) {
    Get-ChildItem -LiteralPath $avdDir -Filter "*.lock" -Force -ErrorAction SilentlyContinue |
      Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Start-EmulatorAndWait {
  Write-Step "Starting Android Emulator"
  $emulator = Join-Path $AndroidHome "emulator\emulator.exe"
  $adb = Join-Path $AndroidHome "platform-tools\adb.exe"

  Remove-Item -LiteralPath $EmulatorLog, $EmulatorErrLog -ErrorAction SilentlyContinue

  $oldErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & $adb kill-server *> $null
    & $adb start-server *> $null
  } finally {
    $ErrorActionPreference = $oldErrorActionPreference
  }
  Reset-StaleEmulatorState -Adb $adb

  $oldErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & $adb start-server *> $null
  } finally {
    $ErrorActionPreference = $oldErrorActionPreference
  }

  $devices = & $adb devices
  $running = $devices | Select-String -Pattern "^emulator-\d+\s+device"

  if (-not $running) {
    $script:EmulatorProcess = Start-Process `
      -FilePath $emulator `
      -ArgumentList @("-avd", $AvdName, "-no-snapshot-load", "-no-snapshot-save", "-no-boot-anim", "-no-metrics", "-gpu", "swiftshader_indirect", "-no-audio", "-netdelay", "none", "-netspeed", "full") `
      -WorkingDirectory $TopicDir `
      -RedirectStandardOutput $EmulatorLog `
      -RedirectStandardError $EmulatorErrLog `
      -PassThru

    Write-Host "Emulator process started. PID: $($script:EmulatorProcess.Id)"
  }

  Write-Host "Waiting for emulator device..."
  $serial = $null
  for ($i = 1; $i -le 180; $i++) {
    Start-Sleep -Seconds 2
    if ($script:EmulatorProcess -and $script:EmulatorProcess.HasExited) {
      throw "Android Emulator stopped before adb could see it. See $EmulatorLog and $EmulatorErrLog."
    }

    $devices = & $adb devices
    $deviceLine = $devices | Select-String -Pattern "^(emulator-\d+)\s+device" | Select-Object -First 1
    if ($deviceLine) {
      $serial = $deviceLine.Matches[0].Groups[1].Value
      break
    }

    Write-Host "Emulator device not attached yet... ($i/180)"
  }

  if (-not $serial) {
    throw "Emulator did not appear in adb devices. See $EmulatorLog and $EmulatorErrLog."
  }

  Write-Host "Waiting for Android boot completion..."
  for ($i = 1; $i -le 180; $i++) {
    Start-Sleep -Seconds 2
    if ($script:EmulatorProcess -and $script:EmulatorProcess.HasExited) {
      throw "Android Emulator stopped before boot completed. See $EmulatorLog and $EmulatorErrLog."
    }

    $bootCompleted = (& $adb -s $serial shell getprop sys.boot_completed 2>$null).Trim()
    if ($bootCompleted -eq "1") {
      & $adb -s $serial shell input keyevent 82 2>$null | Out-Null
      return
    }
    Write-Host "Emulator booting... ($i/180)"
  }

  throw "Emulator did not boot in time. See $EmulatorLog and $EmulatorErrLog."
}

function Start-BackendAndWait {
  Write-Step "Starting Spring Boot backend on port $BackendPort"
  Ensure-Directory $LogsDir

  try {
    Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:$BackendPort/" -TimeoutSec 2 | Out-Null
    Write-Host "Backend is already running on port $BackendPort."
    $script:StartedBackend = $false
    return
  } catch {
    # Start a local backend below.
  }

  Remove-Item -LiteralPath $BackendLog, $BackendErrLog -ErrorAction SilentlyContinue

  $processInfo = New-Object System.Diagnostics.ProcessStartInfo
  $processInfo.FileName = $env:ComSpec
  $processInfo.Arguments = "/d /c call mvnw.cmd -Dspring-boot.run.arguments=--server.port=$BackendPort spring-boot:run > `"$BackendLog`" 2> `"$BackendErrLog`""
  $processInfo.WorkingDirectory = $RepoRoot
  $processInfo.UseShellExecute = $false
  $processInfo.CreateNoWindow = $true
  $script:BackendProcess = [System.Diagnostics.Process]::Start($processInfo)
  $script:StartedBackend = $true

  for ($i = 1; $i -le 90; $i++) {
    Start-Sleep -Seconds 2
    if ($script:BackendProcess.HasExited) {
      throw "Spring Boot stopped before becoming ready. See $BackendLog and $BackendErrLog."
    }

    try {
      Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:$BackendPort/" -TimeoutSec 2 | Out-Null
      return
    } catch {
      Write-Host "Backend starting... ($i/90)"
    }
  }

  throw "Backend did not become ready in time. See $BackendLog and $BackendErrLog."
}

function Invoke-AdbQuiet {
  param(
    [string] $Adb,
    [string[]] $Arguments
  )

  $oldErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    return & $Adb @Arguments 2>$null
  } finally {
    $ErrorActionPreference = $oldErrorActionPreference
  }
}

function Get-AndroidUiDump {
  param([string] $Adb)

  Invoke-AdbQuiet -Adb $Adb -Arguments @("shell", "uiautomator", "dump", "/sdcard/window.xml") | Out-Null
  $dump = Invoke-AdbQuiet -Adb $Adb -Arguments @("shell", "cat", "/sdcard/window.xml")
  if (-not $dump) {
    return ""
  }

  return ($dump -join "`n")
}

function Invoke-TapAndroidText {
  param(
    [string] $Adb,
    [string] $Text
  )

  $ui = Get-AndroidUiDump -Adb $Adb
  if (-not $ui) {
    return $false
  }

  $escapedText = [regex]::Escape($Text)
  $match = [regex]::Match($ui, "(?:text|content-desc)=`"$escapedText`"[^>]*bounds=`"\[(\d+),(\d+)\]\[(\d+),(\d+)\]`"")
  if (-not $match.Success) {
    return $false
  }

  $x = [int](([int]$match.Groups[1].Value + [int]$match.Groups[3].Value) / 2)
  $y = [int](([int]$match.Groups[2].Value + [int]$match.Groups[4].Value) / 2)
  Invoke-AdbQuiet -Adb $Adb -Arguments @("shell", "input", "tap", "$x", "$y") | Out-Null
  Start-Sleep -Seconds 1
  return $true
}

function Dismiss-AndroidSystemDialogs {
  Write-Step "Dismissing Android system dialogs if present"
  $adb = Join-Path $AndroidHome "platform-tools\adb.exe"
  if (-not (Test-Path -LiteralPath $adb)) {
    return
  }

  for ($i = 1; $i -le 3; $i++) {
    $dismissed = $false
    if (Invoke-TapAndroidText -Adb $adb -Text "Wait") {
      Write-Host "Tapped Android system dialog: Wait"
      $dismissed = $true
    }
    if (Invoke-TapAndroidText -Adb $adb -Text "Close app") {
      Write-Host "Tapped Android system dialog: Close app"
      $dismissed = $true
    }

    if (-not $dismissed) {
      return
    }
  }
}

function Stop-BackendProcesses {
  if ($BackendProcess -and -not $BackendProcess.HasExited) {
    Stop-Process -Id $BackendProcess.Id -Force -ErrorAction SilentlyContinue
  }

  Get-NetTCPConnection -LocalPort $BackendPort -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique |
    Where-Object { $_ -gt 0 } |
    ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }

  Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Name -eq "java.exe" -and
      $_.CommandLine -like "*$RepoRoot*" -and
      $_.CommandLine -like "*spring-boot*"
    } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Build-And-Install-App {
  Write-Step "Building and installing native Flutter APK"
  $flutterBat = Join-Path $FlutterHome "bin\flutter.bat"
  $adb = Join-Path $AndroidHome "platform-tools\adb.exe"

  Push-Location $MobileAppDir
  try {
    & $flutterBat pub get
    if ($LASTEXITCODE -ne 0) {
      throw "flutter pub get failed."
    }

    & $flutterBat build apk --debug
    if ($LASTEXITCODE -ne 0) {
      throw "flutter build apk --debug failed."
    }

    $apkPath = Join-Path $MobileAppDir "build\app\outputs\flutter-apk\app-debug.apk"
    if (-not (Test-Path -LiteralPath $apkPath)) {
      throw "Debug APK was not found at $apkPath."
    }

    & $adb install -r $apkPath
    if ($LASTEXITCODE -ne 0) {
      throw "adb install failed."
    }
  } finally {
    Pop-Location
  }
}

function Run-MaestroTest {
  Write-Step "Running Maestro native mobile test"
  $maestroExe = Get-MaestroExecutable
  if (-not $maestroExe) {
    throw "Maestro executable was not found."
  }

  Ensure-Directory $LogsDir
  Push-Location $LogsDir
  try {
    & $maestroExe test $MaestroFlow
    if ($LASTEXITCODE -ne 0) {
      throw "Maestro test failed."
    }
  } finally {
    Pop-Location
  }
}

function Prepare-ManualDemo {
  Write-Step "Preparing manual mobile demo"
  $adb = Join-Path $AndroidHome "platform-tools\adb.exe"
  Invoke-AdbQuiet -Adb $adb -Arguments @("shell", "am", "start", "-n", "com.example.mobile_app/.MainActivity") | Out-Null
  Start-Sleep -Seconds 1
  Write-Host "Manual demo is ready."
  Write-Host "The DateTimeChecker app has been opened for manual input."
  Write-Host "If you go back to the app drawer, Android may show the label shortened as DateTime..."
  Write-Host "Backend stays running at http://localhost:$BackendPort so the Android app can call http://10.0.2.2:$BackendPort."
}

$exitCode = 0

try {
  Ensure-Directory $LogsDir
  Ensure-AndroidSdk
  Ensure-Flutter
  Ensure-Maestro
  Ensure-NativeFlutterProject

  $applicationId = Get-ApplicationId
  Write-Host "Android applicationId: $applicationId" -ForegroundColor Green
  if ($applicationId -ne "com.example.mobile_app") {
    Write-Warning "Maestro flow currently expects com.example.mobile_app. Update maestro/check-valid-date.yaml if your generated applicationId differs."
  }

  Ensure-Avd
  Start-EmulatorAndWait
  Dismiss-AndroidSystemDialogs
  Start-BackendAndWait
  Build-And-Install-App
  Dismiss-AndroidSystemDialogs
  if ($ManualDemo) {
    Prepare-ManualDemo
  } else {
    Run-MaestroTest
  }

  Write-Host ""
  if ($ManualDemo) {
    Write-Host "Native mobile manual demo is ready." -ForegroundColor Green
  } else {
    Write-Host "Native mobile test completed successfully." -ForegroundColor Green
  }
} catch {
  $exitCode = 1
  Write-Host ""
  Write-Host "Native mobile testing failed:" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  if ($_.ScriptStackTrace) {
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
  }
} finally {
  Write-Step "Cleanup"
  if ($StopBackendAfterTest) {
    Stop-BackendProcesses
  } else {
    Write-Host "Spring Boot backend is left running on port $BackendPort for manual demo."
  }

  $adb = Join-Path $AndroidHome "platform-tools\adb.exe"
  if ($CloseEmulatorAfterTest -and (Test-Path -LiteralPath $adb)) {
    try {
      $oldErrorActionPreference = $ErrorActionPreference
      $ErrorActionPreference = "Continue"
      & $adb emu kill *> $null
    } catch {
      # Emulator may not have been started yet; cleanup must not hide the real failure.
    } finally {
      $ErrorActionPreference = $oldErrorActionPreference
    }
  } elseif (Test-Path -LiteralPath $adb) {
    Write-Host "Android Emulator is left open for demo. Close it manually when finished."
  }
}

if ($exitCode -ne 0) {
  exit $exitCode
}
