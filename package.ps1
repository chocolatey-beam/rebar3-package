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
  New-Variable -Name rebar3_json -Option Constant `
    -Value (Invoke-WebRequest -Uri https://api.github.com/repos/erlang/rebar3/releases/latest | ConvertFrom-Json)
}
finally
{
  $ProgressPreference = 'Continue'
}

New-Variable -Name rebar3_version -Option Constant -Value $rebar3_json.tag_name

Write-Host "[INFO] rebar3_version: $rebar3_version"

New-Variable -Name rebar3_asset_node  -Option Constant `
    -Value ($rebar3_json.assets | Where-Object { $_.name -eq 'rebar3' })

New-Variable -Name rebar3_file -Option Constant -Value $rebar3_asset_node.name

if (!(Test-Path -Path $rebar3_file))
{
  Write-Host "[INFO] downloading from " $rebar3_asset_node.browser_download_url
  try
  {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $rebar3_asset_node.browser_download_url -OutFile $rebar3_file
  }
  finally
  {
    $ProgressPreference = 'Continue'
  }
}

New-Variable -Name rebar3_file_sha256 -Option Constant `
    -Value (Get-FileHash -Path $rebar3_file -Algorithm SHA256).Hash.ToLowerInvariant()

(Get-Content -Raw -Path rebar3.nuspec.in).Replace('@@REBAR3_VERSION@@', $rebar3_version) | Set-Content rebar3.nuspec

New-Variable -Name chocolateyInstallPs1In -Option Constant `
  -Value (Join-Path -Path $curdir -ChildPath 'tools' | Join-Path -ChildPath 'chocolateyInstall.ps1.in')

New-Variable -Name chocolateyInstallPs1 -Option Constant `
  -Value (Join-Path -Path $curdir -ChildPath 'tools' | Join-Path -ChildPath 'chocolateyInstall.ps1')

(Get-Content -Raw -Path $chocolateyInstallPs1In).Replace('@@REBAR3_VERSION@@', $rebar3_version).Replace('@@SHA256@@', $rebar3_file_sha256) | Set-Content $chocolateyInstallPs1

New-Variable -Name chocolateyUninstallPs1In -Option Constant `
  -Value (Join-Path -Path $curdir -ChildPath 'tools' | Join-Path -ChildPath 'chocolateyUninstall.ps1.in')

New-Variable -Name chocolateyUninstallPs1 -Option Constant `
  -Value (Join-Path -Path $curdir -ChildPath 'tools' | Join-Path -ChildPath 'chocolateyUninstall.ps1')

(Get-Content -Raw -Path $chocolateyUninstallPs1In).Replace('@@REBAR3_VERSION@@', $rebar3_version) | Set-Content $chocolateyUninstallPs1

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

  & choco install rebar3 $arg_debug $arg_verbose --yes --source ".;https://chocolatey.org/api/v2/"
  if ($LASTEXITCODE -eq 0)
  {
      Write-Host "[INFO] 'choco install' succeeded."
  }
  else
  {
      throw "[ERROR] 'choco install' failed!"
  }

  & rebar3 version
  try
  {
      if ($LASTEXITCODE -eq 0)
      {
          Write-Host "[INFO] rebar3 check succeeded."
      }
      else
      {
          throw "[ERROR] rebar3 check failed!"
      }
  }
  finally
  {
    if ($Uninstall)
    {
      Write-Host "[INFO] choco un-installing Rebar3..."
      & choco uninstall rebar3 $arg_debug $arg_verbose --yes --source ".;https://chocolatey.org/api/v2/"
      Write-Host "[INFO] uninstallation complete!"
    }
    else
    {
      Write-Host "[INFO] choco NOT un-installing Rebar3!"
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

  & choco push rebar3.$rebar3_version.nupkg --source https://push.chocolatey.org
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
