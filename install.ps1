# Midnight Riders Dragons installer for WoW: Forever (Windows PowerShell).
#   irm https://raw.githubusercontent.com/realworldbuilder/midnight-riders-dragons/main/install.ps1 | iex
# Finds your Forever folder, downloads the latest release and puts it in Interface\AddOns.
# Set $env:WOW_DIR to your "World of Warcraft" folder first if it lives somewhere unusual.

& {
  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'   # the progress bar makes downloads very slow on Windows PowerShell
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

  $addon  = 'MidnightRiders_Dragons'
  $zipUrl = "https://github.com/realworldbuilder/midnight-riders-dragons/releases/latest/download/$addon.zip"

  function Say($msg)  { Write-Host ">> $msg" -ForegroundColor Magenta }
  function Fail($msg) { Write-Host "x  $msg" -ForegroundColor Red; throw $msg }

  # 1. Find the Forever folder.
  $candidates = @()
  if ($env:WOW_DIR) { $candidates += $env:WOW_DIR.TrimEnd('\', '/') }
  foreach ($key in 'HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft',
                   'HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft') {
    try {
      $p = (Get-ItemProperty -Path $key -ErrorAction Stop).InstallPath
      if ($p) { $candidates += (Split-Path $p.TrimEnd('\') -Parent) }  # InstallPath points at _retail_ or similar
    } catch { }
  }
  $candidates += "${env:ProgramFiles(x86)}\World of Warcraft", "$env:ProgramFiles\World of Warcraft"
  foreach ($drive in Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue) {
    $candidates += "$($drive.Root)World of Warcraft", "$($drive.Root)Games\World of Warcraft",
                   "$($drive.Root)Program Files (x86)\World of Warcraft"
  }

  $forever = $null
  foreach ($wow in $candidates) {
    if ($wow -and (Test-Path -LiteralPath (Join-Path $wow '_forever_'))) { $forever = Join-Path $wow '_forever_'; break }
  }
  if (-not $forever) {
    Fail ("Couldn't find World of Warcraft: Forever (a _forever_ folder). If it's somewhere else, run:`n" +
          "  `$env:WOW_DIR = 'D:\path\to\World of Warcraft'; irm https://raw.githubusercontent.com/realworldbuilder/midnight-riders-dragons/main/install.ps1 | iex")
  }
  Say "Found Forever: $forever"

  $addons = Join-Path $forever 'Interface\AddOns'
  $target = Join-Path $addons $addon
  try {
    New-Item -ItemType Directory -Force -Path $addons | Out-Null
  } catch {
    Fail "Windows wouldn't let us write to $addons. Open PowerShell with 'Run as administrator' and paste the command again."
  }

  # 2. Download and unpack into a temporary folder.
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("mrdragons-" + [guid]::NewGuid())
  New-Item -ItemType Directory -Path $tmp | Out-Null
  try {
    Say 'Downloading the latest Midnight Riders Dragons...'
    $zip = Join-Path $tmp "$addon.zip"
    try { Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing }
    catch { Fail 'Download failed. Check your internet connection and try again.' }
    Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $tmp 'unpacked') -Force
    $unpacked = Join-Path $tmp "unpacked\$addon"
    if (-not (Test-Path -LiteralPath (Join-Path $unpacked "$addon.toc"))) { Fail "The download didn't contain the addon. Try again in a minute." }

    # 3. Swap it in.
    $updating = Test-Path -LiteralPath $target
    try {
      if ($updating) { Remove-Item -LiteralPath $target -Recurse -Force }
      Move-Item -LiteralPath $unpacked -Destination $target
    } catch {
      Fail "Windows wouldn't let us write to $addons. Close the game, open PowerShell with 'Run as administrator' and paste the command again."
    }

    $version = (Select-String -LiteralPath (Join-Path $target "$addon.toc") -Pattern '^## Version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()
    if ($updating) { Say "Updated Midnight Riders Dragons to v$version." } else { Say "Installed Midnight Riders Dragons v$version." }
    Write-Host ''
    Write-Host '  Restart World of Warcraft: Forever (or type /reload if you were updating).'
    Write-Host "  On the character screen, make sure it's ticked under AddOns. Then type /mrdragon in game."
  } finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}
