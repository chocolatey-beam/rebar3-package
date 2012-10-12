$package = 'SQL2008.ClrTypes'

try {
  $params = @{
    packageName = $package;
    fileType = 'msi';
    silentArgs = '/quiet';
    url = 'http://go.microsoft.com/fwlink/?LinkId=123721&clcid=0x409';
    url64bit = 'http://go.microsoft.com/fwlink/?LinkId=123722&clcid=0x409';
  }

  Install-ChocolateyPackage @params

  Write-ChocolateySuccess $package
} catch {
  Write-ChocolateyFailure $package "$($_.Exception.Message)"
  throw
}
