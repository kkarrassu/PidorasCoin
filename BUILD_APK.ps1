$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$tools = Join-Path $root '.build-tools'
New-Item -ItemType Directory -Force -Path $tools | Out-Null

function Say($s) { Write-Host "`n==> $s" -ForegroundColor Cyan }

# 1) Java 17: use existing Java/Android Studio JBR, otherwise download Temurin.
$javaHome = $env:JAVA_HOME
$studioJbr = 'C:\Program Files\Android\Android Studio\jbr'
if ((!$javaHome -or !(Test-Path (Join-Path $javaHome 'bin\java.exe'))) -and (Test-Path (Join-Path $studioJbr 'bin\java.exe'))) {
    $javaHome = $studioJbr
}
if (!$javaHome -or !(Test-Path (Join-Path $javaHome 'bin\java.exe'))) {
    Say 'Java не найдена — скачиваю JDK 17'
    $jdkZip = Join-Path $tools 'jdk17.zip'
    $jdkDir = Join-Path $tools 'jdk17'
    if (!(Test-Path $jdkDir)) {
        Invoke-WebRequest 'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse' -OutFile $jdkZip
        $tmpJdk = Join-Path $tools 'jdk_tmp'
        Remove-Item $tmpJdk -Recurse -Force -ErrorAction SilentlyContinue
        Expand-Archive $jdkZip $tmpJdk -Force
        $inner = Get-ChildItem $tmpJdk -Directory | Select-Object -First 1
        Move-Item $inner.FullName $jdkDir
        Remove-Item $tmpJdk -Recurse -Force
    }
    $javaHome = $jdkDir
}
$env:JAVA_HOME = $javaHome
$env:Path = "$javaHome\bin;$env:Path"

# 2) Android SDK.
$sdk = Join-Path $tools 'android-sdk'
$cmdLatest = Join-Path $sdk 'cmdline-tools\latest'
if (!(Test-Path (Join-Path $cmdLatest 'bin\sdkmanager.bat'))) {
    Say 'Скачиваю Android SDK command-line tools'
    $cliZip = Join-Path $tools 'android-cli.zip'
    Invoke-WebRequest 'https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip' -OutFile $cliZip
    $tmp = Join-Path $tools 'android_cli_tmp'
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive $cliZip $tmp -Force
    New-Item -ItemType Directory -Force -Path (Split-Path $cmdLatest -Parent) | Out-Null
    Move-Item (Join-Path $tmp 'cmdline-tools') $cmdLatest
    Remove-Item $tmp -Recurse -Force
}
$env:ANDROID_SDK_ROOT = $sdk

Say 'Принимаю лицензии Android SDK'
$yes = (1..200 | ForEach-Object { 'y' }) -join "`n"
$yes | & (Join-Path $cmdLatest 'bin\sdkmanager.bat') --sdk_root=$sdk --licenses | Out-Null

Say 'Устанавливаю Android API 35 и build-tools'
& (Join-Path $cmdLatest 'bin\sdkmanager.bat') --sdk_root=$sdk 'platforms;android-35' 'build-tools;35.0.0' 'platform-tools'
if ($LASTEXITCODE -ne 0) { throw 'Не удалось установить Android SDK packages.' }

# 3) Gradle.
$gradleHome = Join-Path $tools 'gradle-8.11.1'
if (!(Test-Path (Join-Path $gradleHome 'bin\gradle.bat'))) {
    Say 'Скачиваю Gradle 8.11.1'
    $gradleZip = Join-Path $tools 'gradle.zip'
    Invoke-WebRequest 'https://services.gradle.org/distributions/gradle-8.11.1-bin.zip' -OutFile $gradleZip
    Expand-Archive $gradleZip $tools -Force
}

# local.properties for this SDK
("sdk.dir=" + ($sdk -replace '\\','\\\\')) | Set-Content (Join-Path $root 'local.properties') -Encoding ASCII

# 4) Build.
Say 'Собираю APK'
Push-Location $root
try {
    & (Join-Path $gradleHome 'bin\gradle.bat') --no-daemon assembleDebug
    if ($LASTEXITCODE -ne 0) { throw 'Gradle завершился с ошибкой.' }
} finally { Pop-Location }

$apk = Join-Path $root 'app\build\outputs\apk\debug\app-debug.apk'
if (!(Test-Path $apk)) { throw 'APK не найден после сборки.' }
$out = Join-Path $root 'PidorasCoin.apk'
Copy-Item $apk $out -Force
Say 'ГОТОВО'
Write-Host "APK: $out" -ForegroundColor Green
Write-Host 'Можешь перекинуть PidorasCoin.apk на телефон и установить.'
