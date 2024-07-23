# Define the URLs of the list file
$urls = @(
    "https://a.dove.isdumb.one/list.txt",
    "https://a.dove.isdumb.one/cdn",
    "https://a.dove.isdumb.one/fastly"
)

# Define the path of the hosts file
$hostsFile = "$env:windir\System32\drivers\etc\hosts"
$originalBackupFile = "$env:windir\System32\drivers\etc\hosts.original"
$logFile = "$env:windir\System32\drivers\etc\hosts_update.log"

# Function to verify administrator permissions
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to handle and display errors
function Handle-Error {
    param (
        [string]$Message
    )
    Write-Host "Error: ${Message}"
    exit
}

# Function to create a backup
function Create-Backup {
    param (
        [string]$SourcePath,
        [string]$BackupPath
    )
    try {
        Copy-Item -Path $SourcePath -Destination $BackupPath -Force -ErrorAction Stop
        Write-Host "Backup created as '${BackupPath}'."
    } catch {
        Handle-Error "Error creating backup: $_.Exception.Message"
    }
}

# Function to download the content from the given URLs
function Download-Content {
    param($urls)
    foreach ($url in $urls) {
        try {
            Write-Host "Trying to download from ${url}"
            $downloadedContent = (Invoke-WebRequest -Uri $url).Content.Split("`n")
            return $downloadedContent
        } catch {
            Write-Host "Error downloading from ${url}: $_.Exception.Message"
        }
    }
    return $null
}

# Function to validate and filter the downloaded content
function Get-ValidContent {
    param($Content)
    $validContent = @()
    $invalidContent = @()
    foreach ($line in $Content) {
        $line = $line.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $parts = $line -split '\s+'
            if ($parts.Count -eq 2 -and ($parts[0] -eq "0.0.0.0" -or $parts[0] -eq "127.0.0.1")) {
                $validContent += $line
            } else {
                $invalidContent += $line
            }
        }
    }
    return @{
        ValidContent = $validContent
        InvalidContent = $invalidContent
    }
}

# Function to write content to the hosts file
function Write-HostsFile {
    param($Content)
    try {
        Set-Content -Path $hostsFile -Value $Content -Force -ErrorAction Stop
        return $true
    } catch {
        Write-Host "Error writing to the hosts file: $_.Exception.Message"
        return $false
    }
}

# Function to log updates
function Log-Update {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    Add-Content -Path $logFile -Value $logMessage
}

# Function to handle file backup and update
function Backup-And-Update-HostsFile {
    param(
        [string]$UpdatedContent
    )
    Create-Backup -SourcePath $hostsFile -BackupPath "$hostsFile.backup"
    $retryCount = 0
    $maxRetries = 3
    $success = $false

    while (-not $success -and $retryCount -lt $maxRetries) {
        $success = Write-HostsFile -Content $UpdatedContent
        if (-not $success) {
            $retryCount++
            if ($retryCount -lt $maxRetries) {
                Write-Host "Retrying in 5 seconds..."
                Start-Sleep -Seconds 5
            }
        }
    }

    if (-not $success) {
        Write-Host "Could not update the hosts file after $maxRetries attempts. Restoring the backup."
        Copy-Item -Path "$hostsFile.backup" -Destination $hostsFile -Force
        Log-Update "Failed to update hosts file after $maxRetries attempts. Restored backup."
    } else {
        Write-Host "The hosts file has been successfully updated. $($linesToAdd.Count) new valid lines were added."
        Log-Update "Hosts file updated successfully. Added $($linesToAdd.Count) new lines."
    }
}

# Main script logic

if (-not (Test-Admin)) {
    Write-Host "This script requires administrator privileges. Please run it as an administrator."
    exit
}

# Check if this is the first run and create the original backup if needed
if (-not (Test-Path $originalBackupFile)) {
    Create-Backup -SourcePath $hostsFile -BackupPath $originalBackupFile
    Log-Update "Created original backup of hosts file."
} else {
    Write-Host "'hosts.original' backup already exists. Skipping original backup creation."
    Log-Update "'hosts.original' backup already exists."
}

# Attempt to download the content from the URLs
$downloadedContent = Download-Content -urls $urls
if ($null -eq $downloadedContent) {
    Write-Host "Failed to download from all URLs."
    Log-Update "Failed to download from all URLs."
    exit
}

# Validate and filter the downloaded content
$contentResult = Get-ValidContent -Content $downloadedContent
$newContent = $contentResult.ValidContent

# Report invalid content
if ($contentResult.InvalidContent.Count -gt 0) {
    Write-Host "WARNING: The following invalid or potentially malicious entries were found:"
    $contentResult.InvalidContent | ForEach-Object { Write-Host "  $_" }
    Write-Host "These entries will not be added to the hosts file."
    Log-Update "Found invalid or malicious entries. Not adding them to the hosts file."
}

# Check if valid content is empty
if ($newContent.Count -eq 0) {
    Write-Host "No valid content to add to the hosts file."
    Log-Update "No valid content to add to the hosts file."
    exit
}

# Read the current content of the hosts file
try {
    $currentContent = Get-Content -Path $hostsFile
} catch {
    Handle-Error "Error reading the hosts file: $_.Exception.Message"
}

# Convert the current content to a list of lines
$currentLines = $currentContent -split "`n"

# Filter new lines that are not in the current hosts file
$linesToAdd = $newContent | Where-Object { $_.Trim() -notin $currentLines }
if ($linesToAdd.Count -eq 0) {
    Write-Host "No new valid content to add to the hosts file."
    Log-Update "No new valid content to add to the hosts file."
    exit
}

# Prepare the updated content as a list of lines
$updatedContent = @($currentLines + ("# Content added on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") + $linesToAdd)

# Join the lines into a single string with newlines
$updatedContentString = $updatedContent -join "`n"

# Backup and update the hosts file
Backup-And-Update-HostsFile -UpdatedContent $updatedContentString

# Additional diagnostic information
Write-Host "`nDiagnostic information:"
Write-Host "Hosts file path: ${hostsFile}"
Write-Host "Hosts file permissions:"
Get-Acl $hostsFile | Format-List

# Log final state
Log-Update "Hosts file update process completed."
