# PowerShell Script to Automatically Update the Hosts File (Safely) for GenP

PowerShell script to automatically update the Windows hosts file based on the hosts list provided by the [a-dove-is-dumb repository](https://github.com/ignaciocastro/a-dove-is-dumb).

This script has the following features:

* **Multiple URL sources**: The script can download content from multiple URLs based on hosts list suggested in the official guide, providing redundancy if one source is unavailable.
* **Backup functionality**: Creates backups of the hosts file before making changes.
* **Content validation**: Filters and validates the downloaded content to ensure only valid entries are added to the hosts file.
* **Duplicate entry prevention**: Checks for and prevents the addition of duplicate entries.
* **Error handling**: Basic error handling and logging for various operations.
* **Logging**: Maintains a log file to record updates and changes.
* **Retry mechanism**: Implements a retry mechanism when writing to the hosts file fails.
* **Original backup preservation**: Creates and maintains an original backup of the hosts file on first run.
* **Invalid content reporting**: Reports any invalid or potentially malicious entries found in the downloaded content.

## Usage

You can run this script manually or create a scheduled task to run it at a time defined by the user.

## Requirements

PowerShell
Administrator permissions
