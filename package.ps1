param(
    [switch]$PackAndTest = $false,
    [switch]$Push = $false,
    [switch]$Debug = $false,
    [switch]$Verbose = $false,
    [string]$ApiKey = $null,
    [switch]$Uninstall = $true
)

if ($Push)
{
    $PackAndTest = $true
    Write-Host "[INFO] PACKAGE WILL BE TESTED AND PUSHED"
}

$DebugPreference = 'Continue'
$ErrorActionPreference = 'Stop'
# Set-PSDebug -Strict -Trace 1
Set-PSDebug -Off
Set-StrictMode -Version 'Latest' -ErrorAction 'Stop' -Verbose

New-Variable -Name curdir  -Option Constant -Value $PSScriptRoot
Write-Host "[INFO] curdir: $curdir"

if ($Debug)
{
    New-Variable -Name arg_debug  -Option Constant -Value '--debug'
}
else
{
    New-Variable -Name arg_debug  -Option Constant -Value ''
}

if ($Verbose)
{
    New-Variable -Name arg_verbose  -Option Constant -Value '--verbose'
}
else
{
    New-Variable -Name arg_verbose  -Option Constant -Value ''
}

try
{
  $ProgressPreference = 'SilentlyContinue'
  New-Variable -Name erlang_tags -Option Constant `
    -Value (Invoke-WebRequest -Uri https://api.github.com/repos/erlang/otp/tags?per_page=100 | ConvertFrom-Json)
}
finally
{
  $ProgressPreference = 'Continue'
}

New-Variable -Name latest_erlang_tag -Option Constant `
  -Value ($erlang_tags | Where-Object { $_.name -match '^OTP-2[56789]' } | Sort-Object -Descending { $_.name } | Select-Object -First 1)

New-Variable -Name otp_major_version -Option Constant `
  -Value (($latest_erlang_tag.name -replace '^OTP-','') -replace '\..*','')

try
{
  $ProgressPreference = 'SilentlyContinue'
  New-Variable -Name elixir_json -Option Constant `
    -Value (Invoke-WebRequest -Uri https://api.github.com/repos/elixir-lang/elixir/releases/latest | ConvertFrom-Json)
}
finally
{
  $ProgressPreference = 'Continue'
}

New-Variable -Name elixir_version -Option Constant ` -Value ($elixir_json.tag_name -replace '^v', '')

Write-Host "[INFO] elixir_version: $elixir_version"
Write-Host "[INFO] otp_major_version: $otp_major_version"

New-Variable -Name zip_asset_node  -Option Constant `
    -Value ($elixir_json.assets | Where-Object { $_.name -eq 'elixir-otp-25.zip' })
New-Variable -Name zip_asset_sha256_node  -Option Constant `
    -Value ($elixir_json.assets | Where-Object { $_.name -eq 'elixir-otp-25.zip.sha256sum' })

New-Variable -Name elixir_zip_file -Option Constant -Value $zip_asset_node.name
New-Variable -Name elixir_zip_sha256sum_file -Option Constant -Value $zip_asset_sha256_node.name

if (!(Test-Path -Path $elixir_zip_file))
{
  Write-Host "[INFO] downloading from " $zip_asset_node.browser_download_url
  try
  {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $zip_asset_node.browser_download_url -OutFile $elixir_zip_file
    Invoke-WebRequest -Uri $zip_asset_sha256_node.browser_download_url -OutFile $elixir_zip_sha256sum_file
  }
  finally
  {
    $ProgressPreference = 'Continue'
  }
}

New-Variable -Name elixir_zip_sha256_from_file -Option Constant `
    -Value ((Get-Content -Path $elixir_zip_sha256sum_file) -split ' ' | Select-Object -First 1)

New-Variable -Name elixir_zip_file_sha256 -Option Constant `
    -Value (Get-FileHash -Path $elixir_zip_file -Algorithm SHA256).Hash.ToLowerInvariant()

if ($elixir_zip_sha256_from_file -eq $elixir_zip_file_sha256)
{
    Write-Host "[INFO] zip installer calculated sha256 *matches* downloaded file: $elixir_zip_file_sha256"
}
else
{
    throw "[ERROR] zip installer calculated sha256 *DOES NOT MATCH* downloaded file!"
}

(Get-Content -Raw -Path elixir.nuspec.in).Replace('@@ELIXIR_VERSION@@', $elixir_version) | Set-Content elixir.nuspec

New-Variable -Name chocolateyInstallPs1In -Option Constant `
  -Value (Join-Path -Path $curdir -ChildPath 'tools' | Join-Path -ChildPath 'chocolateyInstall.ps1.in')

New-Variable -Name chocolateyInstallPs1 -Option Constant `
  -Value (Join-Path -Path $curdir -ChildPath 'tools' | Join-Path -ChildPath 'chocolateyInstall.ps1')

(Get-Content -Raw -Path $chocolateyInstallPs1In).Replace('@@ELIXIR_VERSION@@', $elixir_version).Replace('@@OTP_MAJOR_VERSION@@', $otp_major_version).Replace('@@SHA256@@', $elixir_zip_file_sha256) | Set-Content $chocolateyInstallPs1

New-Variable -Name chocolateyUninstallPs1In -Option Constant `
  -Value (Join-Path -Path $curdir -ChildPath 'tools' | Join-Path -ChildPath 'chocolateyUninstall.ps1.in')

New-Variable -Name chocolateyUninstallPs1 -Option Constant `
  -Value (Join-Path -Path $curdir -ChildPath 'tools' | Join-Path -ChildPath 'chocolateyUninstall.ps1')

(Get-Content -Raw -Path $chocolateyUninstallPs1In).Replace('@@ELIXIR_ZIP_FILE@@', $elixir_zip_file) | Set-Content $chocolateyUninstallPs1

if ($PackAndTest)
{
  & choco pack
  if ($LASTEXITCODE -eq 0)
  {
    Write-Host "[INFO] 'choco pack' succeeded."
  }
  else
  {
    throw "[ERROR] 'choco pack' failed!"
  }

  & choco install elixir $arg_debug $arg_verbose --yes --source ".;https://chocolatey.org/api/v2/"
  if ($LASTEXITCODE -eq 0)
  {
      Write-Host "[INFO] 'choco install' succeeded."
  }
  else
  {
      throw "[ERROR] 'choco install' failed!"
  }

  & elixir.bat -e 'IO.puts("[INFO] elixir test succeeded!");System.stop(0)';
  try
  {
      if ($LASTEXITCODE -eq 0)
      {
          Write-Host "[INFO] elixir.bat check succeeded."
      }
      else
      {
          throw "[ERROR] elixir.bat check failed!"
      }
  }
  finally
  {
    if ($Uninstall)
    {
      Write-Host "[INFO] choco un-installing Elixir..."
      & choco uninstall elixir $arg_debug $arg_verbose --yes --source ".;https://chocolatey.org/api/v2/"
      Write-Host "[INFO] uninstallation complete!"
    }
    else
    {
      Write-Host "[INFO] choco NOT un-installing Elixir!"
    }
  }
}

if ($Push)
{
  & choco apikey --yes --key $ApiKey --source https://push.chocolatey.org/
  if ($LASTEXITCODE -eq 0)
  {
    Write-Host "[INFO] 'choco apikey' succeeded."
  }
  else
  {
    throw "[ERROR] 'choco apikey' failed!"
  }

  & choco push elixir.$elixir_version.nupkg --source https://push.chocolatey.org
  if ($LASTEXITCODE -eq 0)
  {
    Write-Host "[INFO] 'choco push' succeeded."
  }
  else
  {
    throw "[ERROR] 'choco push' failed!"
  }
}

Set-PSDebug -Off
