<#
.SYNOPSIS
    Detects whether Do Not Disturb mode is on in Windows 11. You can call this from other PowerShell scripts to condition actions on DND status.

.PARAMETER Quiet
    Returns only a number and not a text description of DND status.

.EXAMPLE
    .\dnd.ps1 -q
    Returns 0 if DND is off, 1 if DND is on (priority only), 2 if DND is on (alarms only)

    if ( (dnd -q) -eq 0 ) { Write-Output "This will only appear if DND is off." }
.NOTES
    Author: Adam J. Kessel
    Date: May 19, 2026
    Copyright: (c) 2026 Adam J. Kessel.

    This is free and open-source license, subject to the 2-Clause BSD License.  https://opensource.org/license/bsd-2-clause
#>
#Requires -version 5.1
param ( [Parameter(Mandatory = $false, HelpMessage = "quiet output")][switch]$quiet)
$wnfCode = @"
using System;
using System.Runtime.InteropServices;

public class WnfDnd 
{
  [DllImport("ntdll.dll")]
    public static extern int NtQueryWnfStateData(
        ref ulong StateName,
        IntPtr TypeId,
        IntPtr ExplicitScope,
        out uint ChangeStamp,
        IntPtr Buffer,
        ref uint BufferSize);

  public static int GetState() 
  {
    // The specific WNF state name for Do Not Disturb / Focus Assist
    ulong WNF_SHEL_QUIETHOURS_ACTIVE_PROFILE_CHANGED = 0xD83063EA3BF1C75UL;

    uint changeStamp = 0;
    uint bufferSize = 4;
    IntPtr buffer = Marshal.AllocHGlobal((int)bufferSize);

    try 
    {
      int result = NtQueryWnfStateData(
          ref WNF_SHEL_QUIETHOURS_ACTIVE_PROFILE_CHANGED,
          IntPtr.Zero,
          IntPtr.Zero,
          out changeStamp,
          buffer,
          ref bufferSize);

      // 0 represents STATUS_SUCCESS
      if (result == 0 && bufferSize >= 4) 
      {
        return Marshal.ReadInt32(buffer);
      }

      return -1; // Indicates an error or unknown state
    } 
    finally 
    {
      Marshal.FreeHGlobal(buffer);
    }
  }
}
"@

# Compile the C# code into the current PowerShell session
Add-Type -TypeDefinition $wnfCode -Language CSharp

# Query the WNF state
$state = [WnfDnd]::GetState()
# Evaluate the result
  if ( -not $quiet ) {
    switch ($state) {
      0 { Write-Host "Do Not Disturb is OFF" }
      1 { Write-Host "Do Not Disturb is ON (Priority Only)" }
      2 { Write-Host "Do Not Disturb is ON (Alarms Only)" }
      default { Write-Host "Failed to read state or unknown state returned: $stat#e" }
    }
  }
  return $state
