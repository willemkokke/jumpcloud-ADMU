# Check runningaslocaladmin
if (([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")) -eq $false)
{
    Write-Host 'ADMU must be ran as a local administrator..please correct & try again'
    Read-Host -Prompt "Press Enter to exit"
    exit
}
# Load functions
#region Functions
function BindUsernameToJCSystem
{
  param
  (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)][ValidateLength(40, 40)][string]$JcApiKey,
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)][string]$JumpCloudUserName
  )
  Begin
  {
    $config = get-content "$WindowsDrive\Program Files\JumpCloud\Plugins\Contrib\jcagent.conf"
    $regex = 'systemKey\":\"(\w+)\"'
    $systemKey = [regex]::Match($config, $regex).Groups[1].Value
  }
  Process
  {
    if ($systemKey)
    {
      $Headers = @{
        'Accept'       = 'application/json';
        'Content-Type' = 'application/json';
        'x-api-key'    = $JcApiKey;
      }
      $Form = @{
        'filter' = "username:eq:$($JumpcloudUserName)"
      }
      Try
      {
        Write-Host "Getting information from SystemID: $systemKey"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $Response = Invoke-WebRequest -Method 'Get' -Uri "https://console.jumpcloud.com/api/systemusers" -Headers $Headers -Body $Form -UseBasicParsing
        $StatusCode = $Response.StatusCode
      }
      catch
      {
        $StatusCode = $_.Exception.Response.StatusCode.value__
      }
      # Get Results, convert from Json
      $Results = $Response.Content | ConvertFrom-JSON
      $JcUserId = $Results.results.id
      # Bind Step
      if ($JcUserId)
      {
        $Headers = @{
          'Accept'    = 'application/json';
          'x-api-key' = $JcApiKey
        }
        $Form = @{
          'op'   = 'add';
          'type' = 'system';
          'id'   = "$systemKey"
        } | ConvertTo-Json
        Try
        {
          [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
          $Response = Invoke-WebRequest -Method 'Post' -Uri "https://console.jumpcloud.com/api/v2/users/$JcUserId/associations" -Headers $Headers -Body $Form -ContentType 'application/json' -UseBasicParsing
          $StatusCode = $Response.StatusCode
        }
        catch
        {
          $StatusCode = $_.Exception.Response.StatusCode.value__
        }
      }
      else
      {
        Write-Host "Cound not bind user/ JumpCloudUsername did not exist in JC Directory"
      }
    }
    else
    {
      Write-Host "Could not find systemKey, aborting bind step"
    }
  }
  End
  {
  }
}
function CheckUsernameorSID
{
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    $usernameorsid
  )
  Begin
  {
    $sidPattern = "^S-\d-\d+-(\d+-){1,14}\d+$"
    $registyProfiles = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
    $list = @()
    foreach ($profile in $registyProfiles)
    {
      $list += Get-ItemProperty -Path $profile.PSPath | Select-Object PSChildName, ProfileImagePath
    }
    if (![regex]::IsMatch($usernameorsid, $sidPattern))
    {
      $usernameorsid = (New-Object System.Security.Principal.NTAccount($usernameorsid)).Translate( [System.Security.Principal.SecurityIdentifier]).Value
      write-host "Attempting to convert user to sid..."
    }
  }
  process
  {
    if ($usernameorsid -in $list.PSChildName)
    {
      write-host "Valid SID returning SID"
      return $usernameorsid
    }
    else
    {
      Write-host "Could not find SID on this system, exiting..."
      exit
    }
  }
}
function DenyInteractiveLogonRight
{
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    $SID
  )
  # Add migrating user to denylogon rights
  $secpolFile = "$WindowsDrive\Windows\temp\ur_orig.inf"
  if (Test-Path $secpolFile)
  {
    Remove-Item $secpolFile -Force
  }
  secedit /export /areas USER_RIGHTS /cfg $windowsDrive\Windows\temp\ur_orig.inf
  $secpol = (Get-Content $secpolFile)
  $regvaluestring = $secpol | Where-Object { $_ -like "*SeDenyInteractiveLogonRight*" }
  $regvaluestringID = [array]::IndexOf($secpol, $regvaluestring)
  $oldvalue = (($secpol | Select-String -Pattern 'SeDenyInteractiveLogonRight' | Out-String).trim()).substring(30)
  $newvalue = ('*' + $SID + ',' + $oldvalue.trim())
  $secpol[$regvaluestringID] = 'SeDenyInteractiveLogonRight = ' + $newvalue
  $secpol | out-file $windowsDrive\Windows\temp\ur_new.inf -force
  secedit /configure /db secedit.sdb /cfg $windowsDrive\Windows\temp\ur_new.inf /areas USER_RIGHTS
}
function AllowInteractiveLogonRight
{
  $secpolFile = "$windowsDrive\Windows\temp\ur_orig.inf"
  secedit /configure /db secedit.sdb /cfg $secpolFile /areas USER_RIGHTS
}
function Register-NativeMethod
{
  [CmdletBinding()]
  [Alias()]
  [OutputType([int])]
  Param
  (
    # Param1 help description
    [Parameter(Mandatory = $true,
      ValueFromPipelineByPropertyName = $true,
      Position = 0)]
    [string]$dll,
    # Param2 help description
    [Parameter(Mandatory = $true,
      ValueFromPipelineByPropertyName = $true,
      Position = 1)]
    [string]
    $methodSignature
  )
  $script:nativeMethods += [PSCustomObject]@{ Dll = $dll; Signature = $methodSignature; }
}
function Add-NativeMethods
{
  [CmdletBinding()]
  [Alias()]
  [OutputType([int])]
  Param($typeName = 'NativeMethods')
  $nativeMethodsCode = $script:nativeMethods | ForEach-Object { "
        [DllImport(`"$($_.Dll)`")]
        public static extern $($_.Signature);
    " }
  Add-Type @"
        using System;
        using System.Text;
        using System.Runtime.InteropServices;
        public static class $typeName {
            $nativeMethodsCode
        }
"@
}
function New-LocalUserProfile
{
  [CmdletBinding()]
  [Alias()]
  [OutputType([int])]
  Param
  (
    # Param1 help description
    [Parameter(Mandatory = $true,
      ValueFromPipelineByPropertyName = $true,
      Position = 0)]
    [string]$UserName
  )
  $methodname = 'UserEnvCP2'
  $script:nativeMethods = @();
  if (-not ([System.Management.Automation.PSTypeName]$methodname).Type)
  {
    Register-NativeMethod "userenv.dll" "int CreateProfile([MarshalAs(UnmanagedType.LPWStr)] string pszUserSid,`
         [MarshalAs(UnmanagedType.LPWStr)] string pszUserName,`
         [Out][MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszProfilePath, uint cchProfilePath)";
    Add-NativeMethods -typeName $methodname;
  }
  $sb = new-object System.Text.StringBuilder(260);
  $pathLen = $sb.Capacity;
  Write-Verbose "Creating user profile for $Username";
  $objUser = New-Object System.Security.Principal.NTAccount($UserName)
  $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
  $SID = $strSID.Value
  Write-Verbose "$UserName SID: $SID"
  try
  {
    $result = [UserEnvCP2]::CreateProfile($SID, $Username, $sb, $pathLen)
    if ($result -eq '-2147024713')
    {
      $status = "$userName is an existing account"
      write-verbose "$username Creation Result: $result"
    }
    elseif ($result -eq '-2147024809')
    {
      $status = "$username Not Found"
      write-verbose "$username creation result: $result"
    }
    elseif ($result -eq 0)
    {
      $status = "$username Profile has been created"
      write-verbose "$username Creation Result: $result"
    }
    else
    {
      $status = "$UserName unknown return result: $result"
    }
  }
  catch
  {
    Write-Error $_.Exception.Message;
    # break;
  }
  $status
}
function Remove-LocalUserProfile {
  [CmdletBinding()]
  param (
      [Parameter(Mandatory = $true)]
      [System.String]
      $UserName
  )
  Begin{
    # Validate that the user was just created by the ADMU
    $removeUser = $false
    $users = Get-LocalUser
    foreach ($user in $users)
    {
      if ( $user.name -match $UserName -And $user.description -eq "Created By JumpCloud ADMU" )
      {
        $UserSid = Get-SID -User $UserName
        $UserPath = Get-ProfileImagePath -UserSid $UserSid
        # Set RemoveUser bool to true
        $removeUser = $true
      }
    }
    if (!$removeUser) {
      throw " Username match not found, not reversing"
    }
  }
  Process{
    # Remove the profile
    if ($removeUser){
      # Remove the User
      Remove-LocalUser -Name $UserName
      # Remove the User Profile
      if (Test-Path -Path $UserPath)
      {
        Remove-Item -Path $($UserPath) -Force -Recurse
      }
      # Remove the User SID
      # TODO: if the profile SID is loaded in registry skip this and note in log
      # Match the user SID
      $matchedKey = get-childitem -path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' | Where-Object { $_.Name -match $UserSid }
      # Set the Matched Key Path to PSPath so PowerShell can use the path
      $matchedKeyPath = $($matchedKey.Name) -replace "HKEY_LOCAL_MACHINE", "HKLM:"
      # Remove the UserSid Key from the ProfileList
      Remove-Item -Path "$matchedKeyPath" -Recurse
    }
  }
  End{
    # Output some info
    write-log -message:("$UserName's account, profile and Registry Key SID were removed")
  }
}
function enable-privilege
{
  param(
    ## The privilege to adjust. This set is taken from
    ## http://msdn.microsoft.com/en-us/library/bb530716(VS.85).aspx
    [ValidateSet(
      "SeAssignPrimaryTokenPrivilege", "SeAuditPrivilege", "SeBackupPrivilege",
      "SeChangeNotifyPrivilege", "SeCreateGlobalPrivilege", "SeCreatePagefilePrivilege",
      "SeCreatePermanentPrivilege", "SeCreateSymbolicLinkPrivilege", "SeCreateTokenPrivilege",
      "SeDebugPrivilege", "SeEnableDelegationPrivilege", "SeImpersonatePrivilege", "SeIncreaseBasePriorityPrivilege",
      "SeIncreaseQuotaPrivilege", "SeIncreaseWorkingSetPrivilege", "SeLoadDriverPrivilege",
      "SeLockMemoryPrivilege", "SeMachineAccountPrivilege", "SeManageVolumePrivilege",
      "SeProfileSingleProcessPrivilege", "SeRelabelPrivilege", "SeRemoteShutdownPrivilege",
      "SeRestorePrivilege", "SeSecurityPrivilege", "SeShutdownPrivilege", "SeSyncAgentPrivilege",
      "SeSystemEnvironmentPrivilege", "SeSystemProfilePrivilege", "SeSystemtimePrivilege",
      "SeTakeOwnershipPrivilege", "SeTcbPrivilege", "SeTimeZonePrivilege", "SeTrustedCredManAccessPrivilege",
      "SeUndockPrivilege", "SeUnsolicitedInputPrivilege")]
    $Privilege,
    ## The process on which to adjust the privilege. Defaults to the current process.
    $ProcessId = $pid,
    ## Switch to disable the privilege, rather than enable it.
    [Switch] $Disable
  )
  ## Taken from P/Invoke.NET with minor adjustments.
  $definition = @'
 using System;
 using System.Runtime.InteropServices;
 public class AdjPriv
 {
  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
   ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
  [DllImport("advapi32.dll", SetLastError = true)]
  internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
  [StructLayout(LayoutKind.Sequential, Pack = 1)]
  internal struct TokPriv1Luid
  {
   public int Count;
   public long Luid;
   public int Attr;
  }
  internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
  internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
  internal const int TOKEN_QUERY = 0x00000008;
  internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
  public static bool EnablePrivilege(long processHandle, string privilege, bool disable)
  {
   bool retVal;
   TokPriv1Luid tp;
   IntPtr hproc = new IntPtr(processHandle);
   IntPtr htok = IntPtr.Zero;
   retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
   tp.Count = 1;
   tp.Luid = 0;
   if(disable)
   {
    tp.Attr = SE_PRIVILEGE_DISABLED;
   }
   else
   {
    tp.Attr = SE_PRIVILEGE_ENABLED;
   }
   retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
   retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
   return retVal;
  }
 }
'@
  $processHandle = (Get-Process -id $ProcessId).Handle
  $type = Add-Type $definition -PassThru
  $type[0]::EnablePrivilege($processHandle, $Privilege, $Disable)
}
# Reg Functions adapted from:
# https://social.technet.microsoft.com/Forums/windows/en-US/9f517a39-8dc8-49d3-82b3-96671e2b6f45/powershell-set-registry-key-owner-to-the-system-user-throws-error?forum=winserverpowershell
function Get-RegKeyOwner([string]$keyPath)
{
  $regRights = [System.Security.AccessControl.RegistryRights]::ReadPermissions
  $permCheck = [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree
  $Key = [Microsoft.Win32.Registry]::Users.OpenSubKey($keyPath, $permCheck, $regRights)
  $acl = $Key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::Owner)
  $owner = $acl.GetOwner([type]::GetType([System.Security.Principal.SecurityIdentifier]))
  $key.Close()
  return $owner
}
function Set-ValueToKey([Microsoft.Win32.RegistryHive]$registryRoot, [string]$keyPath, [string]$name, [System.Object]$value, [Microsoft.Win32.RegistryValueKind]$regValueKind)
{
  $regRights = [System.Security.AccessControl.RegistryRights]::SetValue
  $permCheck = [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree
  $Key = [Microsoft.Win32.Registry]::$registryRoot.OpenSubKey($keyPath, $permCheck, $regRights)
  Write-log -Message:("Setting value with properties [name:$name, value:$value, value type:$regValueKind]")
  $Key.SetValue($name, $value, $regValueKind)
  $key.Close()
}
function New-RegKey([string]$keyPath, [Microsoft.Win32.RegistryHive]$registryRoot)
{
  $Key = [Microsoft.Win32.Registry]::$registryRoot.CreateSubKey($keyPath)
  write-log -Message:("Setting key at [KeyPath:$keyPath]")
  $key.Close()
}
function Set-FullControlToUser([System.Security.Principal.SecurityIdentifier]$userName, [string]$keyPath)
{
  # "giving full access to $userName for key $keyPath"
  $regRights = [System.Security.AccessControl.RegistryRights]::takeownership
  $permCheck = [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree
  $key = [Microsoft.Win32.Registry]::Users.OpenSubKey($keyPath, $permCheck, $regRights)
  # After you have set owner you need to get the acl with the perms so you can modify it.
  $acl = $key.GetAccessControl()
  $rule = New-Object System.Security.AccessControl.RegistryAccessRule ($userName, "FullControl", @("ObjectInherit", "ContainerInherit"), "None", "Allow")
  $acl.SetAccessRule($rule)
  $key.SetAccessControl($acl)
}
function Set-ReadToUser([System.Security.Principal.SecurityIdentifier]$userName, [string]$keyPath)
{
  # "giving read access to $userName for key $keyPath"
  $regRights = [System.Security.AccessControl.RegistryRights]::takeownership
  $permCheck = [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree
  $key = [Microsoft.Win32.Registry]::Users.OpenSubKey($keyPath, $permCheck, $regRights)
  # After you have set owner you need to get the acl with the perms so you can modify it.
  $acl = $key.GetAccessControl()
  $rule = New-Object System.Security.AccessControl.RegistryAccessRule ($userName, "ReadKey", @("ObjectInherit", "ContainerInherit"), "None", "Allow")
  $acl.SetAccessRule($rule)
  $key.SetAccessControl($acl)
}
function Get-AdminUserSID
{
  $windowsKey = "SOFTWARE\Microsoft\Windows"
  $regRights = [System.Security.AccessControl.RegistryRights]::ReadPermissions
  $permCheck = [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree
  $Key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($windowsKey, $permCheck, $regRights)
  $acl = $Key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::Owner)
  $owner = $acl.GetOwner([type]::GetType([System.Security.Principal.SecurityIdentifier]))
  # Return sid of owner
  return $owner.Value
}
function Set-AccessFromDomainUserToLocal
{
  [CmdletBinding()]
  param (
    [Parameter()]
    [System.Security.AccessControl.AccessRule]
    $accessItem,
    [Parameter()]
    [System.Security.Principal.SecurityIdentifier]
    $user,
    [Parameter()]
    [string]
    $keyPath
  )
  $regRights = [System.Security.AccessControl.RegistryRights]::takeownership
  $permCheck = [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree
  $key = [Microsoft.Win32.Registry]::Users.OpenSubKey($keyPath, $permCheck, $regRights)
  # Get Access Variables from passed in Acl.Access item
  $access = [System.Security.AccessControl.RegistryRights]$accessItem.RegistryRights
  $type = [System.Security.AccessControl.AccessControlType]$accessItem.AccessControlType
  $inheritance = [System.Security.AccessControl.InheritanceFlags]$accessItem.InheritanceFlags
  $propagation = [System.Security.AccessControl.PropagationFlags]$accessItem.PropagationFlags
  $acl = $key.GetAccessControl()
  $rule = New-Object System.Security.AccessControl.RegistryAccessRule($user, $access, $inheritance, $propagation, $type)
  # Add new Acl.Access rule to Acl so that passed in user now has access
  $acl.AddAccessRule($rule)
  # Remove the old user access
  $acl.RemoveAccessRule($accessItem) | Out-Null
  $key.SetAccessControl($acl)
}
#username To SID Function
function Get-SID ([string]$User)
{
  $objUser = New-Object System.Security.Principal.NTAccount($User)
  $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
  $strSID.Value
}
#Verify Domain Account Function
Function VerifyAccount
{
  Param (
    [Parameter(Mandatory = $true)][System.String]$userName, [System.String]$domain = $null
  )
  $idrefUser = $null
  $strUsername = $userName
  If ($domain)
  {
    $strUsername += [String]("@" + $domain)
  }
  Try
  {
    $idrefUser = ([System.Security.Principal.NTAccount]($strUsername)).Translate([System.Security.Principal.SecurityIdentifier])
  }
  Catch [System.Security.Principal.IdentityNotMappedException]
  {
    $idrefUser = $null
  }
  If ($idrefUser)
  {
    Return $true
  }
  Else
  {
    Return $false
  }
}
function Set-UserRegistryLoadState
{
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("Unload", "Load")]
    [System.String]$op,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Test-Path $_ })]
    [System.String]$ProfilePath,
    # User Security Identifier
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^S-\d-\d+-(\d+-){1,14}\d+$")]
    [System.String]$UserSid
  )
  process
  {
    switch ($op)
    {
      "Load"
      {
        Start-Sleep -Seconds 1
        REG LOAD HKU\$($UserSid)_admu "$ProfilePath\NTUSER.DAT.BAK"
        if ($?)
        {
          Write-log -Message:('Load Profile: ' + "$ProfilePath\NTUSER.DAT.BAK")
        }
        else
        {
          Write-log -Message:('Cound not load profile: ' + "$ProfilePath\NTUSER.DAT.BAK")
        }
        Start-Sleep -Seconds 1
        REG LOAD HKU\"$($UserSid)_Classes_admu" "$ProfilePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak"
        if ($?)
        {
          Write-log -Message:('Load Profile: ' + "$ProfilePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak")
        }
        else
        {
          Write-log -Message:('Cound not load profile: ' + "$ProfilePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak")
        }
      }
      "Unload"
      {
        [gc]::collect()
        Start-Sleep -Seconds 1
        REG UNLOAD HKU\$($UserSid)_admu
        if ($?)
        {
          Write-log -Message:('Unloaded Profile: ' + "$ProfilePath\NTUSER.DAT.bak")
        }
        else
        {
          Write-log -Message:('Could not unload profile: ' + "$ProfilePath\NTUSER.DAT.bak")
        }
        Start-Sleep -Seconds 1
        REG UNLOAD HKU\$($UserSid)_Classes_admu
        if ($?)
        {
          Write-log -Message:('Unloaded Profile: ' + "$ProfilePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak")
        }
        else
        {
          Write-log -Message:('Could not unload profile: ' + "$ProfilePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak")
        }
      }
    }
  }
}
Function Test-UserRegistryLoadState
{
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Test-Path $_ })]
    [System.String]$ProfilePath,
    # User Security Identifier
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^S-\d-\d+-(\d+-){1,14}\d+$")]
    [System.String]$UserSid
  )
  begin
  {
    $results = REG QUERY HKU *>&1
    # Tests to check that the reg items are not loaded
    If ($results -match $UserSid)
    {
      Write-log "REG Keys are loaded, attempting to unload"
      Set-UserRegistryLoadState -op "Unload" -ProfilePath $ProfilePath -UserSid $UserSid
    }
  }
  process
  {
    # Load New User Profile Registry Keys
    try
    {
      Set-UserRegistryLoadState -op "Load" -ProfilePath $ProfilePath -UserSid $UserSid
    }
    catch
    {
      Write-Error "Could Not Load"
    }
    # Load Selected User Profile Keys
    # Unload "Selected" and "NewUser"
    try
    {
      Set-UserRegistryLoadState -op "Unload" -ProfilePath $ProfilePath -UserSid $UserSid
    }
    catch
    {
      Write-Error "Could Not Unload"
    }
  }
  end
  {
    $results = REG QUERY HKU *>&1
    # Tests to check that the reg items are not loaded
    If ($results -match $UserSid)
    {
      Write-log "REG Keys are loaded, attempting to unload"
      Set-UserRegistryLoadState -op "Unload" -ProfilePath $ProfilePath -UserSid $UserSid
    }
    $results = REG QUERY HKU *>&1
    # Tests to check that the reg items are not loaded
    If ($results -match $UserSid)
    {
      Write-log "REG Keys are loaded at the end of testing, exiting..."
      exit
    }
  }
}
Function Backup-RegistryHive
{
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [System.String]
    $profileImagePath
  )
  try
  {
    Copy-Item -Path "$profileImagePath\NTUSER.DAT" -Destination "$profileImagePath\NTUSER.DAT.BAK" -ErrorAction Stop
    Copy-Item -Path "$profileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat" -Destination "$profileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak" -ErrorAction Stop
  }
  catch
  {
    write-log -Message("Could Not Backup Registry Hives in $($profileImagePath): Exiting...")
    write-log -Message($_.Exception.Message)
    # TODO: throw error from message above
    throw "error"
  }
}
Function Get-ProfileImagePath
{
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^S-\d-\d+-(\d+-){1,14}\d+$")]
    [System.String]
    $UserSid
  )
  $profileImagePath = Get-ItemPropertyValue -Path ('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $UserSid) -Name 'ProfileImagePath'
  if ([System.String]::IsNullOrEmpty($profileImagePath))
  {
    Write-log -Message("Could not get the profile path for $UserSid exiting...") -Level Error
    exit
  }
  else
  {
    return $profileImagePath
  }
}
Function Get-WindowsDrive
{
  $drive = (wmic OS GET SystemDrive /VALUE)
  $drive = [regex]::Match($drive, 'SystemDrive=(.\:)').Groups[1].Value
  return $drive
}
#Logging function
<#
  .Synopsis
     Write-Log writes a message to a specified log file with the current time stamp.
  .DESCRIPTION
     The Write-Log function is designed to add logging capability to other scripts.
     In addition to writing output and/or verbose you can write to a log file for
     later debugging.
  .NOTES
     Created by: Jason Wasser @wasserja
     Modified: 11/24/2015 09:30:19 AM
  .PARAMETER Message
     Message is the content that you wish to add to the log file.
  .PARAMETER Path
     The path to the log file to which you would like to write. By default the function will
     create the path and file if it does not exist.
  .PARAMETER Level
     Specify the criticality of the log information being written to the log (i.e. Error, Warning, Informational)
  .EXAMPLE
     Write-Log -Message 'Log message'
     Writes the message to c:\Logs\PowerShellLog.log.
  .EXAMPLE
     Write-Log -Message 'Restarting Server.' -Path c:\Logs\Scriptoutput.log
     Writes the content to the specified log file and creates the path and file specified.
  .EXAMPLE
     Write-Log -Message 'Folder does not exist.' -Path c:\Logs\Script.log -Level Error
     Writes the message to the specified log file as an error message, and writes the message to the error pipeline.
  .LINK
     https://gallery.technet.microsoft.com/scriptcenter/Write-Log-PowerShell-999c32d0
  #>
Function Write-Log
{
  [CmdletBinding()]
  Param
  (
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][ValidateNotNullOrEmpty()][Alias("LogContent")][string]$Message
    , [Parameter(Mandatory = $false)][Alias('LogPath')][string]$Path = "$(Get-WindowsDrive)\Windows\Temp\jcAdmu.log"
    , [Parameter(Mandatory = $false)][ValidateSet("Error", "Warn", "Info")][string]$Level = "Info"
  )
  Begin
  {
    # Set VerbosePreference to Continue so that verbose messages are displayed.
    $VerbosePreference = 'SilentlyContinue'
  }
  Process
  {
    # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
    If (!(Test-Path $Path))
    {
      Write-Verbose "Creating $Path."
      $NewLogFile = New-Item $Path -Force -ItemType File
    }
    Else
    {
      # Nothing to see here yet.
    }
    # Format Date for our Log File
    $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    # Write message to error, warning, or verbose pipeline and specify $LevelText
    Switch ($Level)
    {
      'Error'
      {
        Write-Error $Message
        $LevelText = 'ERROR:'
      }
      'Warn'
      {
        Write-Warning $Message
        $LevelText = 'WARNING:'
      }
      'Info'
      {
        Write-Verbose $Message
        $LevelText = 'INFO:'
      }
    }
    # Write log entry to $Path
    "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append
  }
  End
  {
  }
}
Function Remove-ItemIfExists
{
  [CmdletBinding(SupportsShouldProcess = $true)]
  Param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)][String[]]$Path
    , [Switch]$Recurse
  )
  Process
  {
    Try
    {
      If (Test-Path -Path:($Path))
      {
        Remove-Item -Path:($Path) -Recurse:($Recurse)
      }
    }
    Catch
    {
      Write-Log -Message ('Removal Of Temp Files & Folders Failed') -Level Warn
    }
  }
}
#Download $Link to $Path
Function DownloadLink($Link, $Path)
{
  $WebClient = New-Object -TypeName:('System.Net.WebClient')
  $Global:IsDownloaded = $false
  $SplatArgs = @{ InputObject = $WebClient
    EventName                 = 'DownloadFileCompleted'
    Action                    = { $Global:IsDownloaded = $true; }
  }
  $DownloadCompletedEventSubscriber = Register-ObjectEvent @SplatArgs
  $WebClient.DownloadFileAsync("$Link", "$Path")
  While (-not $Global:IsDownloaded)
  {
    Start-Sleep -Seconds 3
  } # While
  $DownloadCompletedEventSubscriber.Dispose()
  $WebClient.Dispose()
}
#Check if program is on system
function Check_Program_Installed($programName)
{
  $installed = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -match $programName })
  $installed32 = (Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -match $programName })
  if ((-not [System.String]::IsNullOrEmpty($installed)) -or (-not [System.String]::IsNullOrEmpty($installed32)))
  {
    return $true
  }
  else
  {
    return $false
  }
}
#Check reg for program uninstallstring and silently uninstall
function Uninstall_Program($programName)
{
  $Ver = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall |
  Get-ItemProperty |
  Where-Object { $_.DisplayName -match $programName } |
  Select-Object -Property DisplayName, UninstallString
  ForEach ($ver in $Ver)
  {
    If ($ver.UninstallString -and $ver.DisplayName -match 'Jumpcloud')
    {
      $uninst = $ver.UninstallString
      & cmd /C $uninst /Silent | Out-Null
    } If ($ver.UninstallString -and $ver.DisplayName -match 'FileZilla Client 3.46.3')
    {
      $uninst = $ver.UninstallString
      & cmd /c $uninst /S | Out-Null
    }
    else
    {
      $uninst = $ver.UninstallString
      & cmd /c $uninst /q /norestart | Out-Null
    }
  }
}
#Start process and wait then close after 5mins
Function Start-NewProcess([string]$pfile, [string]$arguments, [int32]$Timeout = 300000)
{
  $p = New-Object System.Diagnostics.Process;
  $p.StartInfo.FileName = $pfile;
  $p.StartInfo.Arguments = $arguments
  [void]$p.Start();
  If (! $p.WaitForExit($Timeout))
  {
    Write-Log -Message "Windows ADK Setup did not complete after 5mins";
    Get-Process | Where-Object { $_.Name -like "adksetup*" } | Stop-Process
  }
}
#Validation functions
Function Test-IsNotEmpty ([System.String] $field)
{
  If (([System.String]::IsNullOrEmpty($field)))
  {
    Return $true
  }
  Else
  {
    Return $false
  }
}
Function Test-Is40chars ([System.String] $field)
{
  If ($field.Length -eq 40)
  {
    Return $true
  }
  Else
  {
    Return $false
  }
}
Function Test-HasNoSpaces ([System.String] $field)
{
  If ($field -like "* *")
  {
    Return $false
  }
  Else
  {
    Return $true
  }
}
function Test-Localusername
{
  [CmdletBinding()]
  param (
    [system.array] $field
  )
  begin
  {
    $win32UserProfiles = Get-WmiObject -Class:('Win32_UserProfile') -Property * | Where-Object { $_.Special -eq $false }
    $users = $win32UserProfiles | Select-Object -ExpandProperty "SID" | ConvertSID
    $localusers = new-object system.collections.arraylist
    foreach ($username in $users)
    {
      if ($username -match $env:computername)
      {
        $localusertrim = $username -creplace '^[^\\]*\\', ''
        $localusers.Add($localusertrim) | Out-Null
      }
    }
  }
  process
  {
    if ($localusers -eq $field)
    {
      Return $true
    }
    else
    {
      Return $false
    }
  }
  end
  {
  }
}
function Test-Domainusername
{
  [CmdletBinding()]
  param (
    [system.array] $field
  )
  begin
  {
    $win32UserProfiles = Get-WmiObject -Class:('Win32_UserProfile') -Property * | Where-Object { $_.Special -eq $false }
    $users = $win32UserProfiles | Select-Object -ExpandProperty "SID" | ConvertSID
    $domainusers = new-object system.collections.arraylist
    foreach ($username in $users)
    {
      if ($username -match (GetNetBiosName) -or ($username -match 'AZUREAD'))
      {
        $domainusertrim = $username -creplace '^[^\\]*\\', ''
        $domainusers.Add($domainusertrim) | Out-Null
      }
    }
  }
  process
  {
    if ($domainusers -eq $field)
    {
      Return $true
    }
    else
    {
      Return $false
    }
  }
  end
  {
  }
}
Function DownloadAndInstallAgent(
  [System.String]$msvc2013x64Link
  , [System.String]$msvc2013Path
  , [System.String]$msvc2013x64File
  , [System.String]$msvc2013x64Install
  , [System.String]$msvc2013x86Link
  , [System.String]$msvc2013x86File
  , [System.String]$msvc2013x86Install
)
{
  If (!(Check_Program_Installed("Microsoft Visual C\+\+ 2013 x64")))
  {
    Write-Log -Message:('Downloading & Installing JCAgent prereq Visual C++ 2013 x64')
    (New-Object System.Net.WebClient).DownloadFile("${msvc2013x64Link}", ($jcAdmuTempPath + $msvc2013x64File))
    Invoke-Expression -Command:($msvc2013x64Install)
    $timeout = 0
    While (!(Check_Program_Installed("Microsoft Visual C\+\+ 2013 x64")))
    {
      Start-Sleep 5
      Write-Log -Message:("Waiting for Visual C++ 2013 x64 to finish installing")
      $timeout += 1
      if ($timeout -eq 10)
      {
        break
      }
    }
    Write-Log -Message:('JCAgent prereq installed')
  }
  If (!(Check_Program_Installed("Microsoft Visual C\+\+ 2013 x86")))
  {
    Write-Log -Message:('Downloading & Installing JCAgent prereq Visual C++ 2013 x86')
    (New-Object System.Net.WebClient).DownloadFile("${msvc2013x86Link}", ($jcAdmuTempPath + $msvc2013x86File))
    Invoke-Expression -Command:($msvc2013x86Install)
    $timeout = 0
    While (!(Check_Program_Installed("Microsoft Visual C\+\+ 2013 x86")))
    {
      Start-Sleep 5
      Write-Log -Message:("Waiting for Visual C++ 2013 x86 to finish installing")
      $timeout += 1
      if ($timeout -eq 10)
      {
        break
      }
    }
    Write-Log -Message:('JCAgent prereq installed')
  }
  If (!(AgentIsOnFileSystem))
  {
    Write-Log -Message:('Downloading JCAgent Installer')
    #Download Installer
    (New-Object System.Net.WebClient).DownloadFile("${AGENT_INSTALLER_URL}", ($AGENT_INSTALLER_PATH))
    Write-Log -Message:('JumpCloud Agent Download Complete')
    Write-Log -Message:('Running JCAgent Installer')
    #Run Installer
    Start-Sleep -s 10
    InstallAgent
    Start-Sleep -s 5
  }
  If (Check_Program_Installed("Microsoft Visual C\+\+ 2013 x64") -and Check_Program_Installed("Microsoft Visual C\+\+ 2013 x86") -and Check_Program_Installed("jumpcloud"))
  {
    Return $true
  }
  Else
  {
    # TODO: ADD Log Item to denote failure get jcinstall.log dump it into the admu log.
    Return $false
  }
}
#TODO Add check if library installed on system, else don't import
Add-Type -MemberDefinition @"
[DllImport("netapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern uint NetApiBufferFree(IntPtr Buffer);
[DllImport("netapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern int NetGetJoinInformation(
 string server,
 out IntPtr NameBuffer,
 out int BufferType);
"@ -Namespace Win32Api -Name NetApi32
function GetNetBiosName
{
  $pNameBuffer = [IntPtr]::Zero
  $joinStatus = 0
  $apiResult = [Win32Api.NetApi32]::NetGetJoinInformation(
    $null, # lpServer
    [Ref] $pNameBuffer, # lpNameBuffer
    [Ref] $joinStatus    # BufferType
  )
  if ( $apiResult -eq 0 )
  {
    [Runtime.InteropServices.Marshal]::PtrToStringAuto($pNameBuffer)
    [Void] [Win32Api.NetApi32]::NetApiBufferFree($pNameBuffer)
  }
}
function ConvertSID
{
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    $Sid
  )
  process
  {
    try
    {
      (New-Object System.Security.Principal.SecurityIdentifier($Sid)).Translate( [System.Security.Principal.NTAccount]).Value
    }
    catch
    {
      return $Sid
    }
  }
}
function ConvertUserName
{
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    $user
  )
  process
  {
    try
    {
      (New-Object System.Security.Principal.NTAccount($user)).Translate( [System.Security.Principal.SecurityIdentifier]).Value
    }
    catch
    {
      return $user
    }
  }
}
function Test-RegistryAccess
{
  [CmdletBinding()]
  param (
    [Parameter()]
    [string]
    $profilePath,
    [Parameter()]
    [string]
    $userSID
  )
  begin
  {
    # Load keys
    REG LOAD HKU\"testUserAccess" "$profilePath\NTUSER.DAT" *>6
    $classes = "testUserAccess_Classes"
    # wait just a moment mountng can take a moment
    Start-Sleep 1
    REG LOAD HKU\$classes "$profilePath\AppData\Local\Microsoft\Windows\UsrClass.dat" *>6
    New-PSDrive HKEY_USERS Registry HKEY_USERS *>6
    $HKU = Get-Acl "HKEY_USERS:\testUserAccess"
    $HKU_Classes = Get-Acl "HKEY_USERS:\testUserAccess_Classes"
    $HKUKeys = @($HKU, $HKU_Classes)
    # $convertedSID = ConvertSID "$userSID" -ErrorAction SilentlyContinue
    try
    {
      $convertedSID = ConvertSID "$userSID" -ErrorAction SilentlyContinue
    }
    catch
    {
      write-information "Could not convert user SID, testing ACLs for SID access" -InformationAction Continue
    }
  }
  process
  {
    # Check the access for the root key
    $sidAccessCount = 0
    $userAccessCount = 0
    ForEach ($rootKey in $HKUKeys.Path)
    {
      $acl = Get-Acl $rootKey
      foreach ($al in $acl.Access)
      {
        if ($al.IdentityReference -eq "$userSID")
        {
          # write-information "ACL Access identified by SID: $userSID" -InformationAction Continue
          $sidAccessCount += 1
        }
        elseif ($al.IdentityReference -eq $convertedSID)
        {
          # write-information "ACL Access identified by username : $convertedSID" -InformationAction Continue
          $userAccessCount += 1
        }
      }
    }
    if ($sidAccessCount -eq 2)
    {
      # If both root keys have been verified by sid set $accessIdentity
      write-information "Verified ACL access by SID: $userSID" -InformationAction Continue
      $accessIdentity = $userSID
    }
    if ($userAccessCount -eq 2)
    {
      # If both root keys have been verified by sid set $accessIdentity
      write-information "Verified ACL access by username: $convertedSID" -InformationAction Continue
      $accessIdentity = $convertedSID
    }
    if ([string]::ISNullorEmpty($accessIdentity))
    {
      # if failed to find user access in registry, exit
      write-information "Could not verify ACL access on root keys" -InformationAction Continue
      exit
    }
    else
    {
      # return the $identityAccess variable for registry changes later
      return $accessIdentity
    }
  }
  end
  {
    # unload the registry
    [gc]::collect()
    Start-Sleep -Seconds 1
    REG UNLOAD HKU\"testUserAccess" *>6
    # sometimes this can take a moment between unloading
    Start-Sleep -Seconds 1
    REG UNLOAD HKU\"testUserAccess_Classes" *>6
    $null = Remove-PSDrive -Name HKEY_USERS
  }
}
#endregion Functions
#region Agent Install Helper Functions
Function AgentIsOnFileSystem()
{
  Test-Path -Path:(${AGENT_PATH} + '/' + ${AGENT_BINARY_NAME})
}
Function InstallAgent()
{
  $params = ("${AGENT_INSTALLER_PATH}", "-k ${JumpCloudConnectKey}", "/VERYSILENT", "/NORESTART", "/SUPRESSMSGBOXES", "/NOCLOSEAPPLICATIONS", "/NORESTARTAPPLICATIONS", "/LOG=$env:TEMP\jcUpdate.log")
  Invoke-Expression "$params"
}
Function ForceRebootComputerWithDelay
{
  Param(
    [int]$TimeOut = 10
  )
  $continue = $true
  while ($continue)
  {
    If ([console]::KeyAvailable)
    {
      Write-Output "Restart Canceled by key press"
      Exit;
    }
    Else
    {
      Write-Output "Press any key to cancel... restarting in $TimeOut" -NoNewLine
      Start-Sleep -Seconds 1
      $TimeOut = $TimeOut - 1
      Clear-Host
      If ($TimeOut -eq 0)
      {
        $continue = $false
        $Restart = $true
      }
    }
  }
  If ($Restart -eq $True)
  {
    Write-Output "Restarting Computer..."
    Restart-Computer -ComputerName $env:COMPUTERNAME -Force
  }
}
#endregion Agent Install Helper Functions
Function Start-Migration
{
  [CmdletBinding(HelpURI = "https://github.com/TheJumpCloud/jumpcloud-ADMU/wiki/Start-Migration")]
  Param (
    [Parameter(ParameterSetName = 'cmd', Mandatory = $true)][string]$JumpCloudUserName,
    [Parameter(ParameterSetName = 'cmd', Mandatory = $true)][string]$SelectedUserName,
    [Parameter(ParameterSetName = 'cmd', Mandatory = $false)][bool]$LeaveDomain = $false,
    [Parameter(ParameterSetName = 'cmd', Mandatory = $false)][bool]$ForceReboot = $false,
    [Parameter(ParameterSetName = 'cmd', Mandatory = $false)][bool]$AzureADProfile = $false,
    [Parameter(ParameterSetName = 'cmd', Mandatory = $false)][bool]$InstallJCAgent = $false,
    [Parameter(ParameterSetName = 'cmd', Mandatory = $false)][bool]$AutobindJCUser = $false,
    [Parameter(ParameterSetName = 'cmd', Mandatory = $false)][ValidateLength(40, 40)][string]$JumpCloudConnectKey,
    [Parameter(ParameterSetName = 'cmd', Mandatory = $false)][ValidateLength(40, 40)][string]$JumpCloudAPIKey,
    [Parameter(ParameterSetName = "form")][Object]$inputObject)
  Begin
  {
    If (($InstallJCAgent -eq $true) -and ([string]::IsNullOrEmpty($JumpCloudConnectKey))) { Throw [System.Management.Automation.ValidationMetadataException] "You must supply a value for JumpCloudConnectKey when installing the JC Agent" }else {}
    If (($AutobindJCUser -eq $true) -and ([string]::IsNullOrEmpty($JumpCloudAPIKey))) { Throw [System.Management.Automation.ValidationMetadataException] "You must supply a value for JumpCloudAPIKey when autobinding a JC User" }else {}
    # Start script
    $admuVersion = '2.0.0'
    Write-Log -Message:('####################################' + (get-date -format "dd-MMM-yyyy HH:mm") + '####################################')
    Write-Log -Message:('Running ADMU: ' + 'v' + $admuVersion)
    Write-Log -Message:('Script starting; Log file location: ' + $jcAdmuLogFile)
    Write-Log -Message:('Gathering system & profile information')
    # Conditional ParameterSet logic
    If ($PSCmdlet.ParameterSetName -eq "form")
    {
      $SelectedUserName = $inputObject.DomainUserName
      $JumpCloudUserName = $inputObject.JumpCloudUserName
      if (($inputObject.JumpCloudConnectKey).Length -eq 40)
      {
        $JumpCloudConnectKey = $inputObject.JumpCloudConnectKey
      }
      $InstallJCAgent = $inputObject.InstallJCAgent
      $AutobindJCUser = $inputObject.AutobindJCUser
      $LeaveDomain = $InputObject.LeaveDomain
      $ForceReboot = $InputObject.ForceReboot
      $netBiosName = $inputObject.NetBiosName
    }
    else
    {
      $netBiosName = GetNetBiosname
    }
    # Define misc static variables
    $localComputerName = $WmiComputerSystem.Name
    $windowsDrive = Get-WindowsDrive
    $jcAdmuTempPath = "$windowsDrive\Windows\Temp\JCADMU\"
    $jcAdmuLogFile = "$windowsDrive\Windows\Temp\jcAdmu.log"
    $msvc2013x64File = 'vc_redist.x64.exe'
    $msvc2013x86File = 'vc_redist.x86.exe'
    $msvc2013x86Link = 'http://download.microsoft.com/download/0/5/6/056dcda9-d667-4e27-8001-8a0c6971d6b1/vcredist_x86.exe'
    $msvc2013x64Link = 'http://download.microsoft.com/download/0/5/6/056dcda9-d667-4e27-8001-8a0c6971d6b1/vcredist_x64.exe'
    $msvc2013x86Install = "$jcAdmuTempPath$msvc2013x86File /install /quiet /norestart"
    $msvc2013x64Install = "$jcAdmuTempPath$msvc2013x64File /install /quiet /norestart"
    write-log -Message("The Selected Migration user is: $SelectedUserName")
    $SelectedUserSid = CheckUsernameorSID $SelectedUserName
    # JumpCloud Agent Installation Variables
    $AGENT_PATH = "${env:ProgramFiles}\JumpCloud"
    $AGENT_CONF_FILE = "\Plugins\Contrib\jcagent.conf"
    $AGENT_BINARY_NAME = "JumpCloud-agent.exe"
    $AGENT_SERVICE_NAME = "JumpCloud-agent"
    $AGENT_INSTALLER_URL = "https://s3.amazonaws.com/jumpcloud-windows-agent/production/JumpCloudInstaller.exe"
    $AGENT_INSTALLER_PATH = "$windowsDrive\windows\Temp\JCADMU\JumpCloudInstaller.exe"
    $AGENT_UNINSTALLER_NAME = "unins000.exe"
    $EVENT_LOGGER_KEY_NAME = "hklm:\SYSTEM\CurrentControlSet\services\eventlog\Application\JumpCloud-agent"
    $INSTALLER_BINARY_NAMES = "JumpCloudInstaller.exe,JumpCloudInstaller.tmp"
    # Track migration steps
    $admuTracker = [Ordered]@{
      backup              = @{'pass' = $false; 'fail' = $false}
      newUserInit         = @{'pass' = $false; 'fail' = $false}
      copyRegistry        = @{'pass' = $false; 'fail' = $false}
      copyRegistryFiles   = @{'pass' = $false; 'fail' = $false}
      renameOriginalFiles = @{'pass' = $false; 'fail' = $false}
      renameBackupFiles   = @{'pass' = $false; 'fail' = $false}
      renameHomeDirectory = @{'pass' = $false; 'fail' = $false}
      ntfsAccess          = @{'pass' = $false; 'fail' = $false}
      ntfsPermissions     = @{'pass' = $false; 'fail' = $false}
      activeSetupHKLM     = @{'pass' = $false; 'fail' = $false}
      activeSetupHKU      = @{'pass' = $false; 'fail' = $false}
      uwpAppXPacakges     = @{'pass' = $false; 'fail' = $false}
      uwpDownloadExe      = @{'pass' = $false; 'fail' = $false}
    }
    Write-Log -Message:('Creating JCADMU Temporary Path in ' + $jcAdmuTempPath)
    if (!(Test-path $jcAdmuTempPath))
    {
      new-item -ItemType Directory -Force -Path $jcAdmuTempPath 2>&1 | Write-Verbose
    }
    # Test checks
    if ($AzureADProfile -eq $true -or $netBiosName -match 'AzureAD')
    {
      $DomainName = 'AzureAD'
      $netBiosName = 'AzureAD'
      Write-Log -Message:($localComputerName + ' is currently Domain joined and $AzureADProfile = $true')
    }
    elseif ($AzureADProfile -eq $false)
    {
      $DomainName = $WmiComputerSystem.Domain
      $netBiosName = GetNetBiosName
      Write-Log -Message:($localComputerName + ' is currently Domain joined to ' + $DomainName + ' NetBiosName is ' + $netBiosName)
    }
    #endregion Test checks
  }
  Process
  {
    # Start Of Console Output
    Write-Log -Message:('Windows Profile "' + $SelectedUserName + '" is going to be converted to "' + $localComputerName + '\' + $JumpCloudUserName + '"')
    #region SilentAgentInstall
    if ($InstallJCAgent -eq $true -and (!(Check_Program_Installed("Jumpcloud"))))
    {
      #check if jc is not installed and clear folder
      if (Test-Path "$windowsDrive\Program Files\Jumpcloud\")
      {
        Remove-ItemIfExists -Path "$windowsDrive\Program Files\Jumpcloud\" -Recurse
      }
      # Agent Installer
      DownloadAndInstallAgent -msvc2013x64link:($msvc2013x64Link) -msvc2013path:($jcAdmuTempPath) -msvc2013x64file:($msvc2013x64File) -msvc2013x64install:($msvc2013x64Install) -msvc2013x86link:($msvc2013x86Link) -msvc2013x86file:($msvc2013x86File) -msvc2013x86install:($msvc2013x86Install)
      start-sleep -seconds 20
      if ((Get-Content -Path ($env:LOCALAPPDATA + '\Temp\jcagent.log') -Tail 1) -match 'Agent exiting with exitCode=1')
      {
        Write-Log -Message:('JumpCloud agent installation failed - Check connect key is correct and network connection is active. Connectkey:' + $JumpCloudConnectKey) -Level:('Error')
        taskkill /IM "JumpCloudInstaller.exe" /F
        taskkill /IM "JumpCloudInstaller.tmp" /F
        Read-Host -Prompt "Press Enter to exit"
        exit
      }
      elseif (((Get-Content -Path ($env:LOCALAPPDATA + '\Temp\jcagent.log') -Tail 1) -match 'Agent exiting with exitCode=0'))
      {
        Write-Log -Message:('JC Agent installed - Must be off domain to start jc agent service')
      }
    }
    elseif ($InstallJCAgent -eq $true -and (Check_Program_Installed("Jumpcloud")))
    {
      Write-Log -Message:('JumpCloud agent is already installed on the system.')
    }
    if ($ForceReboot -eq $true)
    {
      $inputobject = [PSCustomObject]@{ }
      # Build FormResults object
      Add-Member -InputObject:($inputobject) -MemberType:('NoteProperty') -Name:('LeaveDomain') -Value:($LeaveDomain)
      Add-Member -InputObject:($inputobject) -MemberType:('NoteProperty') -Name:('DomainUserName') -Value:($SelectedUserName)
      Add-Member -InputObject:($inputobject) -MemberType:('NoteProperty') -Name:('JumpCloudUserName') -Value:($JumpCloudUserName)
      Add-Member -InputObject:($inputobject) -MemberType:('NoteProperty') -Name:('JumpCloudConnectKey') -Value:($JumpCloudConnectKey)
      Add-Member -InputObject:($inputobject) -MemberType:('NoteProperty') -Name:('NetBiosName') -Value:($SelectedUserName)
      #output inputobject as csv
      #$inputobject | Export-CSV -Path 'C:\Windows\Temp\test.csv' -NoTypeInformation
      #Create scheduled task
      $nolimit = New-TimeSpan -Minutes 0
    $newScheduledTaskSplat = @{
        Action      = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "Import-CSV c:\Windows\Temp\admu_discovery.csv | Start-MigrationReboot"
        Description = 'Jumpcloud ADMU Startup Script'
        Settings    = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit $nolimit -Priority 0 
        Trigger     = New-ScheduledTaskTrigger -AtStartup
        Principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    }
    $Start = (Get-Date).AddSeconds(5)
    $ScheduledTask = New-ScheduledTask @newScheduledTaskSplat
    $ScheduledTask.Settings.DeleteExpiredTaskAfter = "PT0S"
    $ScheduledTask.Triggers[0].StartBoundary = $Start.ToString("yyyy-MM-dd'T'HH:mm:ss")
    $ScheduledTask.Triggers[0].EndBoundary = $Start.AddMinutes(10).ToString('s')
    Register-ScheduledTask -InputObject $ScheduledTask -TaskName 'Jumpcloud ADMU Startup Script'
#reboot
Restart-Computer -ComputerName $env:COMPUTERNAME -Force
}
    #####################
    #build params + admu script
    #schedule task to run above script on reboot/load
    #reboot computer
    #block login of user?
    #
    #if forcereboot=true run begin, skip above and run below..
    ### Begin Backup Registry for Selected User ###
    Write-Log -Message:('Creating Backup of User Registry Hive')
    # Get Profile Image Path from Registry
    $oldUserProfileImagePath = Get-ProfileImagePath -UserSid $SelectedUserSID
    # Backup Registry NTUSER.DAT and UsrClass.dat files
    try{
      Backup-RegistryHive -profileImagePath $olduserprofileimagepath
    }
    catch{
      $admuTracker.backup.fail = $true
      return
    }
    $admuTracker.backup.pass = $true
    ### End Backup Registry for Selected User ###
    ### Begin Create New User Region ###
    Write-Log -Message:('Creating New Local User ' + $localComputerName + '\' + $JumpCloudUserName)
    New-LocalUser -Name $JumpCloudUserName -NoPassword -AccountNeverExpires -UserMayNotChangePassword -ErrorVariable userExitCode -Description "Created By JumpCloud ADMU" | Set-LocalUser -PasswordNeverExpires $true
    if ($userExitCode)
    {
      Write-Log -Message:("$userExitCode")
      Write-Log -Message:("The user: $JumpCloudUserName could not be created, exiting")
      $admuTracker.newUserInit.fail = $true
      return
    }
    # Initialize the Profile
    New-LocalUserProfile -username $JumpCloudUserName -ErrorVariable profileInit
    if ($profileInit)
    {
      Write-Log -Message:("$profileInit")
      Write-Log -Message:("The user: $JumpCloudUserName could not be initalized, exiting")
      $admuTracker.newUserInit.fail = $true
      return
    }
    $admuTracker.newUserInit.pass = $true
    ### End Create New User Region ###
    ### Begin Regedit Block ###
    Write-Log -Message:('Getting new profile image path')
    # Set the New User Profile Path
    # Now get NewUserSID
    $NewUserSID = Get-SID -User $JumpCloudUserName
    # Get profile image path for new user
    $newUserProfileImagePath = Get-ProfileImagePath -UserSid $NewUserSID
    ### Begin backup user registry for new user
    Backup-RegistryHive -profileImagePath $newuserprofileimagepath
    ### End backup user registry for new user
    # Test Registry Access before edits
    Write-Log -Message:('Verifying Registry Hives can be loaded and unloaded')
    Test-UserRegistryLoadState -ProfilePath $newuserprofileimagepath -UserSid $newUserSid
    Test-UserRegistryLoadState -ProfilePath $olduserprofileimagepath -UserSid $SelectedUserSID
    # End Test Registry
    Write-Log -Message:('Begin new local user registry copy')
    # Give us admin rights to modify
    $path = takeown /F $newuserprofileimagepath /a /r /d y
    $acl = Get-Acl ($newuserprofileimagepath)
    $AdministratorsGroupSIDName = ([wmi]"Win32_SID.SID='S-1-5-32-544'").AccountName
    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($AdministratorsGroupSIDName, "FullControl", "Allow")
    $acl.SetAccessRuleProtection($false, $true)
    $acl.SetAccessRule($AccessRule)
    $acl | Set-Acl $newuserprofileimagepath
    # TODO: test permissions were set and return condition if not
    # $admuTracker.ntfsAccess = $true
    Write-Log -Message:('New User Profile Path: ' + $newuserprofileimagepath + ' New User SID: ' + $NewUserSID)
    Write-Log -Message:('Old User Profile Path: ' + $olduserprofileimagepath + ' Old User SID: ' + $SelectedUserSID)
    # Load New User Profile Registry Keys
    Set-UserRegistryLoadState -op "Load" -ProfilePath $newuserprofileimagepath -UserSid $NewUserSID
    # Load Selected User Profile Keys
    Set-UserRegistryLoadState -op "Load" -ProfilePath $olduserprofileimagepath -UserSid $SelectedUserSID
    # Copy from "SelectedUser" to "NewUser"
    # TODO: Turn this into a function
    reg copy HKU\$($SelectedUserSID)_admu HKU\$($NewUserSID)_admu /s /f
    if ($?)
    {
      Write-Log -Message:('Copy Profile: ' + "$newuserprofileimagepath/NTUSER.DAT.BAK" + ' To: ' + "$olduserprofileimagepath/NTUSER.DAT.BAK")
    }
    else
    {
      Write-Log -Message:('Could not copy Profile: ' + "$newuserprofileimagepath/NTUSER.DAT.BAK" + ' To: ' + "$olduserprofileimagepath/NTUSER.DAT.BAK")
      $admuTracker.copyRegistry.fail = $true
      return
    }
    reg copy HKU\$($SelectedUserSID)_Classes_admu HKU\$($NewUserSID)_Classes_admu /s /f
    if ($?)
    {
      Write-Log -Message:('Copy Profile: ' + "$newuserprofileimagepath/AppData/Local/Microsoft/Windows/UsrClass.dat" + ' To: ' + "$olduserprofileimagepath/AppData/Local/Microsoft/Windows/UsrClass.dat")
    }
    else
    {
      Write-Log -Message:('Could not copy Profile: ' + "$newuserprofileimagepath/AppData/Local/Microsoft/Windows/UsrClass.dat" + ' To: ' + "$olduserprofileimagepath/AppData/Local/Microsoft/Windows/UsrClass.dat")
      $admuTracker.copyRegistry.fail = $true
      return
    }
    $admuTracker.copyRegistry.pass = $true
    # Copy the profile containing the correct access and data to the destination profile
    Write-Log -Message:('Copying merged profiles to destination profile path')
    #TODO: Turn this into a function
    # Set Registry Check Key for New User
    # Check that the installed components key does not exist
    if ((Get-psdrive | select-object name) -notmatch "HKEY_USERS")
    {
      Write-Host "Mounting HKEY_USERS to check USER UWP keys"
      New-PSDrive HKEY_USERS Registry HKEY_USERS
    }
    $ADMU_PackageKey = "HKEY_USERS:\$($newusersid)_admu\SOFTWARE\Microsoft\Active Setup\Installed Components\ADMU-AppxPackage"
    if (Get-Item $ADMU_PackageKey -ErrorAction SilentlyContinue)
    {
      # If the account to be converted already has this key, reset the version
      $rootlessKey = $ADMU_PackageKey.Replace('HKEY_USERS:\', '')
      Set-ValueToKey -registryRoot Users -KeyPath $rootlessKey -name Version -value "0,0,00,0" -regValueKind String
    }
    # TODO: test Key exists, non terminating error here if we can't set Active Setup Keys
    # $admuTracker.activeSetupHKU = $true
    # Set the trigger to reset Appx Packages on first login
    $ADMUKEY = "HKEY_USERS:\$($newusersid)_admu\SOFTWARE\JCADMU"
    if (Get-Item $ADMUKEY -ErrorAction SilentlyContinue)
    {
      # If the registry Key exists (it wont)
      Write-Host "The Key Already Exists"
    }
    else
    {
      # Create the new key & remind add tracking from previous domain account for reversion if necessary
      New-RegKey -registryRoot Users -keyPath "$($newusersid)_admu\SOFTWARE\JCADMU"
      Set-ValueToKey -registryRoot Users -keyPath "$($newusersid)_admu\SOFTWARE\JCADMU" -Name "previousSID" -value "$SelectedUserSID" -regValueKind String
      Set-ValueToKey -registryRoot Users -keyPath "$($newusersid)_admu\SOFTWARE\JCADMU" -Name "previousProfilePath" -value "$olduserprofileimagepath" -regValueKind String
    }
    # TODO: test Key exists, non terminating error here if we can't set previous SID/ ProfilePath
    ### End reg key check for new user
    # Unload "Selected" and "NewUser"
    Set-UserRegistryLoadState -op "Unload" -ProfilePath $newuserprofileimagepath -UserSid $NewUserSID
    Set-UserRegistryLoadState -op "Unload" -ProfilePath $olduserprofileimagepath -UserSid $SelectedUserSID
    # Copy both registry hives over and replace the existing backup files in the destination directory.
    try
    {
      Copy-Item -Path "$newuserprofileimagepath/NTUSER.DAT.BAK" -Destination "$olduserprofileimagepath/NTUSER.DAT.BAK" -Force -ErrorAction Stop
      Copy-Item -Path "$newuserprofileimagepath/AppData/Local/Microsoft/Windows/UsrClass.dat.bak" -Destination "$olduserprofileimagepath/AppData/Local/Microsoft/Windows/UsrClass.dat.bak" -Force -ErrorAction Stop
    }
    catch
    {
      write-log -Message("Could not copy backup registry hives to the destination location in $($olduserprofileimagepath): Exiting...")
      write-log -Message($_.Exception.Message)
      $admuTracker.copyRegistryFiles.fail = $true
      return
    }
    $admuTracker.copyRegistryFiles.pass = $true
    # Rename original ntuser & usrclass .dat files to ntuser_original.dat & usrclass_original.dat for backup and reversal if needed
    Write-Log -Message:('Copy orig. ntuser.dat to ntuser_original.dat (backup reg step)')
    try
    {
      Rename-Item -Path "$olduserprofileimagepath\NTUSER.DAT" -NewName "$olduserprofileimagepath\NTUSER_original.DAT" -Force -ErrorAction Stop
      Rename-Item -Path "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass.dat" -NewName "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass_original.dat" -Force -ErrorAction Stop
    }
    catch
    {
      write-log -Message("Could not rename original registry files for backup purposes: Exiting...")
      write-log -Message($_.Exception.Message)
      $admuTracker.renameOriginalFiles.fail = $true
      return
    }
    $admuTracker.renameOriginalFiles.pass = $true
    # finally set .dat.back registry files to the .dat in the profileimagepath
    Write-Log -Message:('rename ntuser.dat.bak to ntuser.dat (replace step)')
    try
    {
      Rename-Item -Path "$olduserprofileimagepath\NTUSER.DAT.BAK" -NewName "$olduserprofileimagepath\NTUSER.DAT" -Force -ErrorAction Stop
      Rename-Item -Path "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak" -NewName "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass.dat" -Force -ErrorAction Stop
    }
    catch
    {
      write-log -Message("Could not rename backup registry files to a system recognizable name: Exiting...")
      write-log -Message($_.Exception.Message)
      $admuTracker.renameBackupFiles.fail = $true
      return
    }
    $admuTracker.renameBackupFiles.pass = $true
    # Test Condition for same names
    # Check if the new user is named username.HOSTNAME or username.000, .001 etc.
    $userCompare = $olduserprofileimagepath.Replace("$($windowsDrive)\Users\", "")
    if ($userCompare -eq $JumpCloudUserName)
    {
      Write-log -Message:("Selected User Path and New User Path Match")
      # Remove the New User Profile Path, we want to just use the old Path
      Remove-Item -Path ($newuserprofileimagepath) -Force -Recurse
      # Set the New User Profile Image Path to Old User Profile Path (they are the same)
      $newuserprofileimagepath = $olduserprofileimagepath
    }
    else
    {
      write-log -Message:("Selected User Path and New User Path Differ")
      try
      {
        # Remove the New User Profile Path, in this case we will rename the home folder to the desired name
        Remove-Item -Path ($newuserprofileimagepath) -Force -Recurse
        # Rename the old user profile path to the new name
        # Error Action Stop added since Rename-Item doesn't treat this as a terminating error
        Rename-Item -Path $olduserprofileimagepath -NewName $JumpCloudUserName -ErrorAction Stop
      }
      catch
      {
        Write-Log -Message:("Unable to rename user profile path to new name - $JumpCloudUserName.")
        $admuTracker.renameHomeDirectory.fail = $true
        return
      }
    }
    # Set profile image path of new and selected user
    try
    {
      Set-ItemProperty -Path ('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $SelectedUserSID) -Name 'ProfileImagePath' -Value ("$windowsDrive\Users\" + $SelectedUserName + '.' + $NetBiosName)
      Set-ItemProperty -Path ('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $NewUserSID) -Name 'ProfileImagePath' -Value ("$windowsDrive\Users\" + $JumpCloudUserName)
    }
    catch
    {
      Write-Log -Message:("Unable to set profile image path.")
      return
    }
    $admuTracker.renameHomeDirectory.pass = $true
    # logging
    Write-Log -Message:('New User Profile Path: ' + $newuserprofileimagepath + ' New User SID: ' + $NewUserSID)
    Write-Log -Message:('Old User Profile Path: ' + $olduserprofileimagepath + ' Old User SID: ' + $SelectedUserSID)
    Write-Log -Message:("NTFS ACLs on domain $windowsDrive\users\ dir")
    #ntfs acls on domain $windowsDrive\users\ dir
    $NewSPN_Name = $env:COMPUTERNAME + '\' + $JumpCloudUserName
    $Acl = Get-Acl $newuserprofileimagepath
    $Ar = New-Object system.security.accesscontrol.filesystemaccessrule($NewSPN_Name, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $Acl.SetAccessRule($Ar)
    $Acl | Set-Acl -Path $newuserprofileimagepath
    #TODO: test and return condition if false
    # $admuTracker.ntfsPermissions = $true
    ## End Regedit Block ##
    ### Active Setup Registry Entry ###
    Write-Log -Message:('Creating HKLM Registry Entries')
    # Root Key Path
    $ADMUKEY = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\ADMU-AppxPackage"
    # Remove Root from key to pass into functions
    $rootlessKey = $ADMUKEY.Replace('HKLM:\', '')
    # Property Values
    $propertyHash = @{
      IsInstalled = 1
      Locale      = "*"
      StubPath    = "uwp_jcadmu.exe"
      Version     = "1,0,00,0"
    }
    if (Get-Item $ADMUKEY -ErrorAction SilentlyContinue)
    {
      write-log -message:("The ADMU Registry Key exits")
      $properties = Get-ItemProperty -Path "$ADMUKEY"
      foreach ($item in $propertyHash.Keys)
      {
        Write-log -message:("Property: $($item) Value: $($properties.$item)")
      }
    }
    else
    {
      # write-host "The ADMU Registry Key does not exist"
      # Create the new key
      New-RegKey -keyPath $rootlessKey -registryRoot LocalMachine
      foreach ($item in $propertyHash.Keys)
      {
        # Eventually make this better
        if ($item -eq "IsInstalled")
        {
          Set-ValueToKey -registryRoot LocalMachine -keyPath "$rootlessKey" -Name "$item" -value $propertyHash[$item] -regValueKind Dword
        }
        else
        {
          Set-ValueToKey -registryRoot LocalMachine -keyPath "$rootlessKey" -Name "$item" -value $propertyHash[$item] -regValueKind String
        }
      }
    }
    # TODO: test and note error if failure
    # $admuTracker.activeSetupHKLM = $true
    ### End Active Setup Registry Entry Region ###
    # Get UWP apps from selected user
    Write-Log -Message:('Updating UWP Apps for new user')
    $path = $newuserprofileimagepath + '\AppData\Local\JumpCloudADMU'
    If (!(test-path $path))
    {
      New-Item -ItemType Directory -Force -Path $path
    }
    $appxList = @()
    if ($AzureADProfile -eq $true -or $netBiosName -match 'AzureAD')
    {
      # Find Appx User Apps by Username
      $appxList = Get-AppXpackage -user (ConvertSID $SelectedUserSID) | Select-Object InstallLocation
    }
    else
    {
      $appxList = Get-AppXpackage -user $SelectedUserSID | Select-Object InstallLocation
    }
    if ($appxList.Count -eq 0)
    {
      # Get Common Apps in edge case:
      $appxList = Get-AppXpackage -AllUsers | Select-Object InstallLocation
    }
    $appxList | Export-CSV ($newuserprofileimagepath + '\AppData\Local\JumpCloudADMU\appx_manifest.csv') -Force
    # TODO: Test and return non terminating error here if failure
    # $admuTracker.uwpAppXPackages = $true
    # Download the appx register exe
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://github.com/TheJumpCloud/jumpcloud-ADMU/releases/latest/download/uwp_jcadmu.exe" -OutFile "$windowsDrive\Windows\uwp_jcadmu.exe"
    Start-Sleep -Seconds 5
    try
    {
      Get-Item -Path "$windowsDrive\Windows\uwp_jcadmu.exe" -ErrorAction Stop
    }
    catch
    {
      write-Log -Message("Could not find uwp_jcadmu.exe in $windowsDrive\Windows\ UWP Apps will not migrate")
      write-Log -Message($_.Exception.Message)
      # TODO: Test and return non terminating error here if failure
      # TODO: Get the checksum
      # $admuTracker.uwpDownloadExe = $true
    }
    Write-Log -Message:('Profile Conversion Completed')
    #region Add To Local Users Group
    Add-LocalGroupMember -SID S-1-5-32-545 -Member $JumpCloudUserName -erroraction silentlycontinue
    #endregion Add To Local Users Group
    # TODO: test and return non-terminating error here
    #region AutobindUserToJCSystem
    BindUsernameToJCSystem -JcApiKey $JumpCloudAPIKey -JumpCloudUserName $JumpCloudUserName
    #endregion AutobindUserToJCSystem
    # TODO: test if we have the API key?
    #region Leave Domain or AzureAD
    if ($LeaveDomain -eq $true)
    {
      if ($netBiosName -match 'AzureAD')
      {
        try
        {
          Write-Log -Message:('Leaving AzureAD')
          dsregcmd.exe /leave
        }
        catch
        {
          Write-Log -Message:('Unable to leave domain, JumpCloud agent will not start until resolved') -Level:('Error')
          # TODO: instead of exit, return and note the error in the logs (Non Terminating?)
          Exit;
        }
      }
      else
      {
        Try
        {
          Write-Log -Message:('Leaving Domain')
          $WmiComputerSystem.UnJoinDomainOrWorkGroup($null, $null, 0)
        }
        Catch
        {
          Write-Log -Message:('Unable to leave domain, JumpCloud agent will not start until resolved') -Level:('Error')
          # TODO: instead of exit, return and note the error in the logs (Non Terminating?)
          Exit;
        }
      }
    }
    # Cleanup Folders Again Before Reboot
    Write-Log -Message:('Removing Temp Files & Folders.')
    Start-Sleep -s 10
    try
    {
      Remove-ItemIfExists -Path:($jcAdmuTempPath) -Recurse
    }
    catch
    {
      Write-Log -Message:('Failed to remove Temp Files & Folders.' + $jcAdmuTempPath)
    }
    #endregion SilentAgentInstall
  }
  End
  {
    $FixedErrors= @();
    # if we caught any errors and need to revert based on admuTracker status, do so here:
    foreach ($trackedStep in $admuTracker.Keys)
    {
      if (($admuTracker[$trackedStep].fail -eq $true) -or ($admuTracker[$trackedStep].pass -eq $true))
      {
        switch ($trackedStep) {
          # Case for reverting 'newUserInit' steps
          'newUserInit' {
            Write-Log -Message:("Attempting to revert $($trackedStep) steps")
            try {
              Remove-LocalUserProfile -username $JumpCloudUserName
            }
            catch {
              Write-Log -Message:("Could not remove the $JumpCloudUserName profile and user account") -Level Error
            }
            $FixedErrors += "$trackedStep"
          }
          'renameOriginalFiles'
          {
            Write-Log -Message:("Attempting to revert $($trackedStep) steps")
            ### Should we be using Rename-Item here or Move-Item to force overwrite?
            if (Test-Path "$olduserprofileimagepath\NTUSER_original.DAT" -PathType Leaf)
            {
              try
              {
                Rename-Item -Path "$olduserprofileimagepath\NTUSER.DAT" -NewName "$olduserprofileimagepath\NTUSER_failedCopy.DAT" -Force -ErrorAction Stop
                Rename-Item -Path "$olduserprofileimagepath\NTUSER_original.DAT" -NewName "$olduserprofileimagepath\NTUSER.DAT" -Force -ErrorAction Stop
              }
              catch
              {
                Write-Log -Message:("Unable to rename file $olduserprofileimagepath\NTUSER_original.DAT") -Level Error
              }
            }
            if (Test-Path "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass_original.dat" -PathType Leaf)
            {
              try
              {
                Rename-Item -Path "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass.dat" -NewName "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass_failedCopy.dat" -Force -ErrorAction Stop
                Rename-Item -Path "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass_original.dat" -NewName "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass.dat" -Force -ErrorAction Stop
              }
              catch
              {
                Write-Log -Message:("Unable to rename file $olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass_original.dat") -Level Error
              }
              $FixedErrors += "$trackedStep"
            }
          }
          'renameBackupFiles'
          {
            Write-Log -Message:("Attempting to revert $($trackedStep) steps")
            if (Test-Path "$olduserprofileimagepath\NTUSER.DAT.BAK" -PathType Leaf)
            {
              try
              {
                Rename-Item -Path "$olduserprofileimagepath\NTUSER.DAT.BAK" -NewName "$olduserprofileimagepath\NTUSER.DAT" -Force -ErrorAction Stop
              }
              catch
              {
                Write-Log -Message:("Unable to rename file $olduserprofileimagepath\NTUSER.DAT.BAK") -Level Error
              }
            }
            if (Test-Path "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak" -PathType Leaf)
            {
              try
              {
                Rename-Item -Path "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak" -NewName "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass.dat" -Force -ErrorAction Stop
              }
              catch
              {
                Write-Log -Message:("Unable to rename file $olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak") -Level Error
              }
            }
            $FixedErrors += "$trackedStep"
          }
          'renameHomeDirectory'
          {
            try
            {
              Write-Log -Message:("Attempting to revert RenameHomeDirectory steps")
              if (($userCompare -ne $selectedUserName) -and (test-path -Path $newuserprofileimagepath))
              {
                # Error Action stop to treat as terminating error
                Rename-Item -Path ($newuserprofileimagepath) -NewName ($selectedUserName) -ErrorAction Stop
              }
              Set-ItemProperty -Path ('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $SelectedUserSID) -Name 'ProfileImagePath' -Value "$($olduserprofileimagepath)"
            }
            catch
            {
              Write-Log -Message:("Unable to restore old user profile path and profile image path.") -Level Error
            }
            $FixedErrors += "$trackedStep"
          }
          Default {
            # Write-Log -Message:("default error") -Level Error
          }
        }
      }
    }
    if ([System.String]::IsNullOrEmpty($($admuTracker.Keys | Where-Object { $admuTracker[$_].fail -eq $true }))) {
      Write-Log -Message:('Script finished successfully; Log file location: ' + $jcAdmuLogFile)
      Write-Log -Message:('Tool options chosen were : ' + 'Install JC Agent = ' + $InstallJCAgent + ', Leave Domain = ' + $LeaveDomain + ', Force Reboot = ' + $ForceReboot + ', AzureADProfile = ' + $AzureADProfile + ', Create System Restore Point = ' + $CreateRestore)
    }
    else {
      Write-Log -Message:("ADMU encoutered the following errors: $($admuTracker.Keys | Where-Object { $admuTracker[$_].fail -eq $true })") -Level Warn
      Write-Log -Message:("The following migration steps were reverted to their original state: $FixedErrors") -Level Warn
      throw "JumpCloud ADMU was unable to migrate $selectedUserName"
    }
  }
}
function Start-MigrationReboot {
  Param (
    [Parameter][Object]$inputObject)
  begin {
    # Start script
    $admuVersion = '2.0.0'
    Write-Log -Message:('####################################' + (get-date -format "dd-MMM-yyyy HH:mm") + '####################################')
    Write-Log -Message:('Running ADMU: ' + 'v' + $admuVersion)
    Write-Log -Message:('Script starting; Log file location: ' + $jcAdmuLogFile)
    Write-Log -Message:('Gathering system & profile information')
    $netBiosName = GetNetBiosname
    # Define misc static variables
    $localComputerName = $WmiComputerSystem.Name
    $windowsDrive = Get-WindowsDrive
    $jcAdmuTempPath = "$windowsDrive\Windows\Temp\JCADMU\"
    $jcAdmuLogFile = "$windowsDrive\Windows\Temp\jcAdmu.log"
    write-log -Message("The Selected Migration user is: $SelectedUserName")
    $SelectedUserSid = CheckUsernameorSID $SelectedUserName
    # Track migration steps
    $admuTracker = [Ordered]@{
      backup              = @{'pass' = $false; 'fail' = $false}
      newUserInit         = @{'pass' = $false; 'fail' = $false}
      copyRegistry        = @{'pass' = $false; 'fail' = $false}
      copyRegistryFiles   = @{'pass' = $false; 'fail' = $false}
      renameOriginalFiles = @{'pass' = $false; 'fail' = $false}
      renameBackupFiles   = @{'pass' = $false; 'fail' = $false}
      renameHomeDirectory = @{'pass' = $false; 'fail' = $false}
      ntfsAccess          = @{'pass' = $false; 'fail' = $false}
      ntfsPermissions     = @{'pass' = $false; 'fail' = $false}
      activeSetupHKLM     = @{'pass' = $false; 'fail' = $false}
      activeSetupHKU      = @{'pass' = $false; 'fail' = $false}
      uwpAppXPacakges     = @{'pass' = $false; 'fail' = $false}
      uwpDownloadExe      = @{'pass' = $false; 'fail' = $false}
    }
    Write-Log -Message:('Creating JCADMU Temporary Path in ' + $jcAdmuTempPath)
    if (!(Test-path $jcAdmuTempPath))
    {
      new-item -ItemType Directory -Force -Path $jcAdmuTempPath 2>&1 | Write-Verbose
    }
    # Test checks
    if ($AzureADProfile -eq $true -or $netBiosName -match 'AzureAD')
    {
      $DomainName = 'AzureAD'
      $netBiosName = 'AzureAD'
      Write-Log -Message:($localComputerName + ' is currently Domain joined and $AzureADProfile = $true')
    }
    elseif ($AzureADProfile -eq $false)
    {
      $DomainName = $WmiComputerSystem.Domain
      $netBiosName = GetNetBiosName
      Write-Log -Message:($localComputerName + ' is currently Domain joined to ' + $DomainName + ' NetBiosName is ' + $netBiosName)
    }
    #endregion Test checks
  }
  process {
        # Start Of Console Output
        Write-Log -Message:('Windows Profile "' + $SelectedUserName + '" is going to be converted to "' + $localComputerName + '\' + $JumpCloudUserName + '"')
            ### Begin Backup Registry for Selected User ###
    Write-Log -Message:('Creating Backup of User Registry Hive')
    # Get Profile Image Path from Registry
    $oldUserProfileImagePath = Get-ProfileImagePath -UserSid $SelectedUserSID
    # Backup Registry NTUSER.DAT and UsrClass.dat files
    try{
      Backup-RegistryHive -profileImagePath $olduserprofileimagepath
    }
    catch{
      $admuTracker.backup.fail = $true
      return
    }
    $admuTracker.backup.pass = $true
    ### End Backup Registry for Selected User ###
    ### Begin Create New User Region ###
    Write-Log -Message:('Creating New Local User ' + $localComputerName + '\' + $JumpCloudUserName)
    New-LocalUser -Name $JumpCloudUserName -NoPassword -AccountNeverExpires -UserMayNotChangePassword -ErrorVariable userExitCode -Description "Created By JumpCloud ADMU" | Set-LocalUser -PasswordNeverExpires $true
    if ($userExitCode)
    {
      Write-Log -Message:("$userExitCode")
      Write-Log -Message:("The user: $JumpCloudUserName could not be created, exiting")
      $admuTracker.newUserInit.fail = $true
      return
    }
    # Initialize the Profile
    New-LocalUserProfile -username $JumpCloudUserName -ErrorVariable profileInit
    if ($profileInit)
    {
      Write-Log -Message:("$profileInit")
      Write-Log -Message:("The user: $JumpCloudUserName could not be initalized, exiting")
      $admuTracker.newUserInit.fail = $true
      return
    }
    $admuTracker.newUserInit.pass = $true
    ### End Create New User Region ###
    ### Begin Regedit Block ###
    Write-Log -Message:('Getting new profile image path')
    # Set the New User Profile Path
    # Now get NewUserSID
    $NewUserSID = Get-SID -User $JumpCloudUserName
    # Get profile image path for new user
    $newUserProfileImagePath = Get-ProfileImagePath -UserSid $NewUserSID
    ### Begin backup user registry for new user
    Backup-RegistryHive -profileImagePath $newuserprofileimagepath
    ### End backup user registry for new user
    # Test Registry Access before edits
    Write-Log -Message:('Verifying Registry Hives can be loaded and unloaded')
    Test-UserRegistryLoadState -ProfilePath $newuserprofileimagepath -UserSid $newUserSid
    Test-UserRegistryLoadState -ProfilePath $olduserprofileimagepath -UserSid $SelectedUserSID
    # End Test Registry
    Write-Log -Message:('Begin new local user registry copy')
    # Give us admin rights to modify
    $path = takeown /F $newuserprofileimagepath /a /r /d y
    $acl = Get-Acl ($newuserprofileimagepath)
    $AdministratorsGroupSIDName = ([wmi]"Win32_SID.SID='S-1-5-32-544'").AccountName
    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($AdministratorsGroupSIDName, "FullControl", "Allow")
    $acl.SetAccessRuleProtection($false, $true)
    $acl.SetAccessRule($AccessRule)
    $acl | Set-Acl $newuserprofileimagepath
    # TODO: test permissions were set and return condition if not
    # $admuTracker.ntfsAccess = $true
    Write-Log -Message:('New User Profile Path: ' + $newuserprofileimagepath + ' New User SID: ' + $NewUserSID)
    Write-Log -Message:('Old User Profile Path: ' + $olduserprofileimagepath + ' Old User SID: ' + $SelectedUserSID)
    # Load New User Profile Registry Keys
    Set-UserRegistryLoadState -op "Load" -ProfilePath $newuserprofileimagepath -UserSid $NewUserSID
    # Load Selected User Profile Keys
    Set-UserRegistryLoadState -op "Load" -ProfilePath $olduserprofileimagepath -UserSid $SelectedUserSID
    # Copy from "SelectedUser" to "NewUser"
    # TODO: Turn this into a function
    reg copy HKU\$($SelectedUserSID)_admu HKU\$($NewUserSID)_admu /s /f
    if ($?)
    {
      Write-Log -Message:('Copy Profile: ' + "$newuserprofileimagepath/NTUSER.DAT.BAK" + ' To: ' + "$olduserprofileimagepath/NTUSER.DAT.BAK")
    }
    else
    {
      Write-Log -Message:('Could not copy Profile: ' + "$newuserprofileimagepath/NTUSER.DAT.BAK" + ' To: ' + "$olduserprofileimagepath/NTUSER.DAT.BAK")
      $admuTracker.copyRegistry.fail = $true
      return
    }
    reg copy HKU\$($SelectedUserSID)_Classes_admu HKU\$($NewUserSID)_Classes_admu /s /f
    if ($?)
    {
      Write-Log -Message:('Copy Profile: ' + "$newuserprofileimagepath/AppData/Local/Microsoft/Windows/UsrClass.dat" + ' To: ' + "$olduserprofileimagepath/AppData/Local/Microsoft/Windows/UsrClass.dat")
    }
    else
    {
      Write-Log -Message:('Could not copy Profile: ' + "$newuserprofileimagepath/AppData/Local/Microsoft/Windows/UsrClass.dat" + ' To: ' + "$olduserprofileimagepath/AppData/Local/Microsoft/Windows/UsrClass.dat")
      $admuTracker.copyRegistry.fail = $true
      return
    }
    $admuTracker.copyRegistry.pass = $true
    # Copy the profile containing the correct access and data to the destination profile
    Write-Log -Message:('Copying merged profiles to destination profile path')
    #TODO: Turn this into a function
    # Set Registry Check Key for New User
    # Check that the installed components key does not exist
    if ((Get-psdrive | select-object name) -notmatch "HKEY_USERS")
    {
      Write-Host "Mounting HKEY_USERS to check USER UWP keys"
      New-PSDrive HKEY_USERS Registry HKEY_USERS
    }
    $ADMU_PackageKey = "HKEY_USERS:\$($newusersid)_admu\SOFTWARE\Microsoft\Active Setup\Installed Components\ADMU-AppxPackage"
    if (Get-Item $ADMU_PackageKey -ErrorAction SilentlyContinue)
    {
      # If the account to be converted already has this key, reset the version
      $rootlessKey = $ADMU_PackageKey.Replace('HKEY_USERS:\', '')
      Set-ValueToKey -registryRoot Users -KeyPath $rootlessKey -name Version -value "0,0,00,0" -regValueKind String
    }
    # TODO: test Key exists, non terminating error here if we can't set Active Setup Keys
    # $admuTracker.activeSetupHKU = $true
    # Set the trigger to reset Appx Packages on first login
    $ADMUKEY = "HKEY_USERS:\$($newusersid)_admu\SOFTWARE\JCADMU"
    if (Get-Item $ADMUKEY -ErrorAction SilentlyContinue)
    {
      # If the registry Key exists (it wont)
      Write-Host "The Key Already Exists"
    }
    else
    {
      # Create the new key & remind add tracking from previous domain account for reversion if necessary
      New-RegKey -registryRoot Users -keyPath "$($newusersid)_admu\SOFTWARE\JCADMU"
      Set-ValueToKey -registryRoot Users -keyPath "$($newusersid)_admu\SOFTWARE\JCADMU" -Name "previousSID" -value "$SelectedUserSID" -regValueKind String
      Set-ValueToKey -registryRoot Users -keyPath "$($newusersid)_admu\SOFTWARE\JCADMU" -Name "previousProfilePath" -value "$olduserprofileimagepath" -regValueKind String
    }
    # TODO: test Key exists, non terminating error here if we can't set previous SID/ ProfilePath
    ### End reg key check for new user
    # Unload "Selected" and "NewUser"
    Set-UserRegistryLoadState -op "Unload" -ProfilePath $newuserprofileimagepath -UserSid $NewUserSID
    Set-UserRegistryLoadState -op "Unload" -ProfilePath $olduserprofileimagepath -UserSid $SelectedUserSID
    # Copy both registry hives over and replace the existing backup files in the destination directory.
    try
    {
      Copy-Item -Path "$newuserprofileimagepath/NTUSER.DAT.BAK" -Destination "$olduserprofileimagepath/NTUSER.DAT.BAK" -Force -ErrorAction Stop
      Copy-Item -Path "$newuserprofileimagepath/AppData/Local/Microsoft/Windows/UsrClass.dat.bak" -Destination "$olduserprofileimagepath/AppData/Local/Microsoft/Windows/UsrClass.dat.bak" -Force -ErrorAction Stop
    }
    catch
    {
      write-log -Message("Could not copy backup registry hives to the destination location in $($olduserprofileimagepath): Exiting...")
      write-log -Message($_.Exception.Message)
      $admuTracker.copyRegistryFiles.fail = $true
      return
    }
    $admuTracker.copyRegistryFiles.pass = $true
    # Rename original ntuser & usrclass .dat files to ntuser_original.dat & usrclass_original.dat for backup and reversal if needed
    Write-Log -Message:('Copy orig. ntuser.dat to ntuser_original.dat (backup reg step)')
    try
    {
      Rename-Item -Path "$olduserprofileimagepath\NTUSER.DAT" -NewName "$olduserprofileimagepath\NTUSER_original.DAT" -Force -ErrorAction Stop
      Rename-Item -Path "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass.dat" -NewName "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass_original.dat" -Force -ErrorAction Stop
    }
    catch
    {
      write-log -Message("Could not rename original registry files for backup purposes: Exiting...")
      write-log -Message($_.Exception.Message)
      $admuTracker.renameOriginalFiles.fail = $true
      return
    }
    $admuTracker.renameOriginalFiles.pass = $true
    # finally set .dat.back registry files to the .dat in the profileimagepath
    Write-Log -Message:('rename ntuser.dat.bak to ntuser.dat (replace step)')
    try
    {
      Rename-Item -Path "$olduserprofileimagepath\NTUSER.DAT.BAK" -NewName "$olduserprofileimagepath\NTUSER.DAT" -Force -ErrorAction Stop
      Rename-Item -Path "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak" -NewName "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass.dat" -Force -ErrorAction Stop
    }
    catch
    {
      write-log -Message("Could not rename backup registry files to a system recognizable name: Exiting...")
      write-log -Message($_.Exception.Message)
      $admuTracker.renameBackupFiles.fail = $true
      return
    }
    $admuTracker.renameBackupFiles.pass = $true
    # Test Condition for same names
    # Check if the new user is named username.HOSTNAME or username.000, .001 etc.
    $userCompare = $olduserprofileimagepath.Replace("$($windowsDrive)\Users\", "")
    if ($userCompare -eq $JumpCloudUserName)
    {
      Write-log -Message:("Selected User Path and New User Path Match")
      # Remove the New User Profile Path, we want to just use the old Path
      Remove-Item -Path ($newuserprofileimagepath) -Force -Recurse
      # Set the New User Profile Image Path to Old User Profile Path (they are the same)
      $newuserprofileimagepath = $olduserprofileimagepath
    }
    else
    {
      write-log -Message:("Selected User Path and New User Path Differ")
      try
      {
        # Remove the New User Profile Path, in this case we will rename the home folder to the desired name
        Remove-Item -Path ($newuserprofileimagepath) -Force -Recurse
        # Rename the old user profile path to the new name
        # Error Action Stop added since Rename-Item doesn't treat this as a terminating error
        Rename-Item -Path $olduserprofileimagepath -NewName $JumpCloudUserName -ErrorAction Stop
      }
      catch
      {
        Write-Log -Message:("Unable to rename user profile path to new name - $JumpCloudUserName.")
        $admuTracker.renameHomeDirectory.fail = $true
        return
      }
    }
    # Set profile image path of new and selected user
    try
    {
      Set-ItemProperty -Path ('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $SelectedUserSID) -Name 'ProfileImagePath' -Value ("$windowsDrive\Users\" + $SelectedUserName + '.' + $NetBiosName)
      Set-ItemProperty -Path ('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $NewUserSID) -Name 'ProfileImagePath' -Value ("$windowsDrive\Users\" + $JumpCloudUserName)
    }
    catch
    {
      Write-Log -Message:("Unable to set profile image path.")
      return
    }
    $admuTracker.renameHomeDirectory.pass = $true
    # logging
    Write-Log -Message:('New User Profile Path: ' + $newuserprofileimagepath + ' New User SID: ' + $NewUserSID)
    Write-Log -Message:('Old User Profile Path: ' + $olduserprofileimagepath + ' Old User SID: ' + $SelectedUserSID)
    Write-Log -Message:("NTFS ACLs on domain $windowsDrive\users\ dir")
    #ntfs acls on domain $windowsDrive\users\ dir
    $NewSPN_Name = $env:COMPUTERNAME + '\' + $JumpCloudUserName
    $Acl = Get-Acl $newuserprofileimagepath
    $Ar = New-Object system.security.accesscontrol.filesystemaccessrule($NewSPN_Name, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $Acl.SetAccessRule($Ar)
    $Acl | Set-Acl -Path $newuserprofileimagepath
    #TODO: test and return condition if false
    # $admuTracker.ntfsPermissions = $true
    ## End Regedit Block ##
    ### Active Setup Registry Entry ###
    Write-Log -Message:('Creating HKLM Registry Entries')
    # Root Key Path
    $ADMUKEY = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\ADMU-AppxPackage"
    # Remove Root from key to pass into functions
    $rootlessKey = $ADMUKEY.Replace('HKLM:\', '')
    # Property Values
    $propertyHash = @{
      IsInstalled = 1
      Locale      = "*"
      StubPath    = "uwp_jcadmu.exe"
      Version     = "1,0,00,0"
    }
    if (Get-Item $ADMUKEY -ErrorAction SilentlyContinue)
    {
      write-log -message:("The ADMU Registry Key exits")
      $properties = Get-ItemProperty -Path "$ADMUKEY"
      foreach ($item in $propertyHash.Keys)
      {
        Write-log -message:("Property: $($item) Value: $($properties.$item)")
      }
    }
    else
    {
      # write-host "The ADMU Registry Key does not exist"
      # Create the new key
      New-RegKey -keyPath $rootlessKey -registryRoot LocalMachine
      foreach ($item in $propertyHash.Keys)
      {
        # Eventually make this better
        if ($item -eq "IsInstalled")
        {
          Set-ValueToKey -registryRoot LocalMachine -keyPath "$rootlessKey" -Name "$item" -value $propertyHash[$item] -regValueKind Dword
        }
        else
        {
          Set-ValueToKey -registryRoot LocalMachine -keyPath "$rootlessKey" -Name "$item" -value $propertyHash[$item] -regValueKind String
        }
      }
    }
    # TODO: test and note error if failure
    # $admuTracker.activeSetupHKLM = $true
    ### End Active Setup Registry Entry Region ###
    # Get UWP apps from selected user
    Write-Log -Message:('Updating UWP Apps for new user')
    $path = $newuserprofileimagepath + '\AppData\Local\JumpCloudADMU'
    If (!(test-path $path))
    {
      New-Item -ItemType Directory -Force -Path $path
    }
    $appxList = @()
    if ($AzureADProfile -eq $true -or $netBiosName -match 'AzureAD')
    {
      # Find Appx User Apps by Username
      $appxList = Get-AppXpackage -user (ConvertSID $SelectedUserSID) | Select-Object InstallLocation
    }
    else
    {
      $appxList = Get-AppXpackage -user $SelectedUserSID | Select-Object InstallLocation
    }
    if ($appxList.Count -eq 0)
    {
      # Get Common Apps in edge case:
      $appxList = Get-AppXpackage -AllUsers | Select-Object InstallLocation
    }
    $appxList | Export-CSV ($newuserprofileimagepath + '\AppData\Local\JumpCloudADMU\appx_manifest.csv') -Force
    # TODO: Test and return non terminating error here if failure
    # $admuTracker.uwpAppXPackages = $true
    # Download the appx register exe
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://github.com/TheJumpCloud/jumpcloud-ADMU/releases/latest/download/uwp_jcadmu.exe" -OutFile "$windowsDrive\Windows\uwp_jcadmu.exe"
    Start-Sleep -Seconds 5
    try
    {
      Get-Item -Path "$windowsDrive\Windows\uwp_jcadmu.exe" -ErrorAction Stop
    }
    catch
    {
      write-Log -Message("Could not find uwp_jcadmu.exe in $windowsDrive\Windows\ UWP Apps will not migrate")
      write-Log -Message($_.Exception.Message)
      # TODO: Test and return non terminating error here if failure
      # TODO: Get the checksum
      # $admuTracker.uwpDownloadExe = $true
    }
    Write-Log -Message:('Profile Conversion Completed')
    #region Add To Local Users Group
    Add-LocalGroupMember -SID S-1-5-32-545 -Member $JumpCloudUserName -erroraction silentlycontinue
    #endregion Add To Local Users Group
    # TODO: test and return non-terminating error here
    #region AutobindUserToJCSystem
    BindUsernameToJCSystem -JcApiKey $JumpCloudAPIKey -JumpCloudUserName $JumpCloudUserName
    #endregion AutobindUserToJCSystem
    # TODO: test if we have the API key?
    #region Leave Domain or AzureAD
    if ($LeaveDomain -eq $true)
    {
      if ($netBiosName -match 'AzureAD')
      {
        try
        {
          Write-Log -Message:('Leaving AzureAD')
          dsregcmd.exe /leave
        }
        catch
        {
          Write-Log -Message:('Unable to leave domain, JumpCloud agent will not start until resolved') -Level:('Error')
          # TODO: instead of exit, return and note the error in the logs (Non Terminating?)
          Exit;
        }
      }
      else
      {
        Try
        {
          Write-Log -Message:('Leaving Domain')
          $WmiComputerSystem.UnJoinDomainOrWorkGroup($null, $null, 0)
        }
        Catch
        {
          Write-Log -Message:('Unable to leave domain, JumpCloud agent will not start until resolved') -Level:('Error')
          # TODO: instead of exit, return and note the error in the logs (Non Terminating?)
          Exit;
        }
      }
    }
    # Cleanup Folders Again Before Reboot
    Write-Log -Message:('Removing Temp Files & Folders.')
    Start-Sleep -s 10
    try
    {
      Remove-ItemIfExists -Path:($jcAdmuTempPath) -Recurse
    }
    catch
    {
      Write-Log -Message:('Failed to remove Temp Files & Folders.' + $jcAdmuTempPath)
    }
    #endregion SilentAgentInstall
  }
  end {
    $FixedErrors= @();
    # if we caught any errors and need to revert based on admuTracker status, do so here:
    foreach ($trackedStep in $admuTracker.Keys)
    {
      if (($admuTracker[$trackedStep].fail -eq $true) -or ($admuTracker[$trackedStep].pass -eq $true))
      {
        switch ($trackedStep) {
          # Case for reverting 'newUserInit' steps
          'newUserInit' {
            Write-Log -Message:("Attempting to revert $($trackedStep) steps")
            try {
              Remove-LocalUserProfile -username $JumpCloudUserName
            }
            catch {
              Write-Log -Message:("Could not remove the $JumpCloudUserName profile and user account") -Level Error
            }
            $FixedErrors += "$trackedStep"
          }
          'renameOriginalFiles'
          {
            Write-Log -Message:("Attempting to revert $($trackedStep) steps")
            ### Should we be using Rename-Item here or Move-Item to force overwrite?
            if (Test-Path "$olduserprofileimagepath\NTUSER_original.DAT" -PathType Leaf)
            {
              try
              {
                Rename-Item -Path "$olduserprofileimagepath\NTUSER.DAT" -NewName "$olduserprofileimagepath\NTUSER_failedCopy.DAT" -Force -ErrorAction Stop
                Rename-Item -Path "$olduserprofileimagepath\NTUSER_original.DAT" -NewName "$olduserprofileimagepath\NTUSER.DAT" -Force -ErrorAction Stop
              }
              catch
              {
                Write-Log -Message:("Unable to rename file $olduserprofileimagepath\NTUSER_original.DAT") -Level Error
              }
            }
            if (Test-Path "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass_original.dat" -PathType Leaf)
            {
              try
              {
                Rename-Item -Path "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass.dat" -NewName "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass_failedCopy.dat" -Force -ErrorAction Stop
                Rename-Item -Path "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass_original.dat" -NewName "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass.dat" -Force -ErrorAction Stop
              }
              catch
              {
                Write-Log -Message:("Unable to rename file $olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass_original.dat") -Level Error
              }
              $FixedErrors += "$trackedStep"
            }
          }
          'renameBackupFiles'
          {
            Write-Log -Message:("Attempting to revert $($trackedStep) steps")
            if (Test-Path "$olduserprofileimagepath\NTUSER.DAT.BAK" -PathType Leaf)
            {
              try
              {
                Rename-Item -Path "$olduserprofileimagepath\NTUSER.DAT.BAK" -NewName "$olduserprofileimagepath\NTUSER.DAT" -Force -ErrorAction Stop
              }
              catch
              {
                Write-Log -Message:("Unable to rename file $olduserprofileimagepath\NTUSER.DAT.BAK") -Level Error
              }
            }
            if (Test-Path "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak" -PathType Leaf)
            {
              try
              {
                Rename-Item -Path "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak" -NewName "$olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass.dat" -Force -ErrorAction Stop
              }
              catch
              {
                Write-Log -Message:("Unable to rename file $olduserprofileimagepath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak") -Level Error
              }
            }
            $FixedErrors += "$trackedStep"
          }
          'renameHomeDirectory'
          {
            try
            {
              Write-Log -Message:("Attempting to revert RenameHomeDirectory steps")
              if (($userCompare -ne $selectedUserName) -and (test-path -Path $newuserprofileimagepath))
              {
                # Error Action stop to treat as terminating error
                Rename-Item -Path ($newuserprofileimagepath) -NewName ($selectedUserName) -ErrorAction Stop
              }
              Set-ItemProperty -Path ('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $SelectedUserSID) -Name 'ProfileImagePath' -Value "$($olduserprofileimagepath)"
            }
            catch
            {
              Write-Log -Message:("Unable to restore old user profile path and profile image path.") -Level Error
            }
            $FixedErrors += "$trackedStep"
          }
          Default {
            # Write-Log -Message:("default error") -Level Error
          }
        }
      }
    }
    if ([System.String]::IsNullOrEmpty($($admuTracker.Keys | Where-Object { $admuTracker[$_].fail -eq $true }))) {
      Write-Log -Message:('Script finished successfully; Log file location: ' + $jcAdmuLogFile)
      Write-Log -Message:('Tool options chosen were : ' + 'Install JC Agent = ' + $InstallJCAgent + ', Leave Domain = ' + $LeaveDomain + ', Force Reboot = ' + $ForceReboot + ', AzureADProfile = ' + $AzureADProfile + ', Create System Restore Point = ' + $CreateRestore)
    }
    else {
      Write-Log -Message:("ADMU encoutered the following errors: $($admuTracker.Keys | Where-Object { $admuTracker[$_].fail -eq $true })") -Level Warn
      Write-Log -Message:("The following migration steps were reverted to their original state: $FixedErrors") -Level Warn
      throw "JumpCloud ADMU was unable to migrate $selectedUserName"
    }
  }
}
# Load form
Write-Log 'Loading Jumpcloud ADMU. Please Wait.. Loading ADMU GUI..'
#==============================================================================================
# XAML Code - Imported from Visual Studio WPF Application
#==============================================================================================
[void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')
[xml]$XAML = @'
<Window
     xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
     xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
     Title="JumpCloud ADMU 2.0.0" Height="519" Width="919" WindowStartupLocation="CenterScreen" ResizeMode="NoResize" ForceCursor="True" WindowStyle="None" Background="White">
     <Grid Margin="0,0,0,109">
     <Grid.RowDefinitions>
         <RowDefinition Height="25"/>
         <RowDefinition/>
     </Grid.RowDefinitions>
     <Grid.ColumnDefinitions>
         <ColumnDefinition/>
         <ColumnDefinition/>
     </Grid.ColumnDefinitions>
     <StackPanel Grid.Row="1">
         <StackPanel Orientation="Horizontal">
             <Image Width="91" Height="91"
                    Source="https://images.g2crowd.com/uploads/product/image/large_detail/large_detail_106a112f3cbf66eae385f29d407dd288/jumpcloud.png"/>
             <Image Width="266" Height="84"
                    Source="https://jumpcloud.com/wp-content/themes/jumpcloud/assets/images/jumpcloud-press-kit/logos/05-wordmark-dark.png"/>
         </StackPanel>
     </StackPanel>
     <Grid Background="#0F0F2D" 
           Grid.ColumnSpan="2">
         <Grid.ColumnDefinitions>
             <ColumnDefinition/>
             <ColumnDefinition/>
             <ColumnDefinition/>
             <ColumnDefinition/>
         </Grid.ColumnDefinitions>
         <TextBlock Name="tbjcconsole"
                    Text="JumpCloud Console"
                    Foreground="White"
                    Grid.Column="0"
                    VerticalAlignment="Center"
                    HorizontalAlignment="Center"
                    />
         <TextBlock Name="tbjcadmugh"
                    Text="JumpCloud AMDU Github"
                    Foreground="White"
                    Grid.Column="1"
                    VerticalAlignment="Center"
                    HorizontalAlignment="Center"
                    />
         <TextBlock Name="tbjcsupport"
                    Text="JumpCloud Support"
                    Foreground="White"
                    Grid.Column="2"
                    VerticalAlignment="Center"
                    HorizontalAlignment="Center"
                    />
         <TextBlock Name="tbjcadmulog"
                    Text="JumpCloud ADMU Log"
                    Foreground="White"
                    Grid.Column="5"
                    VerticalAlignment="Center"
                    HorizontalAlignment="Center"
                    />
         <ListView Name="lvProfileList" Grid.ColumnSpan="8" Margin="7,180,9,-311">
             <ListView.View>
                 <GridView>
                     <GridViewColumn Header="System Accounts" DisplayMemberBinding="{Binding UserName}" Width="180"/>
                     <GridViewColumn Header="Last Login" DisplayMemberBinding="{Binding LastLogin}" Width="135"/>
                     <GridViewColumn Header="Currently Active" DisplayMemberBinding="{Binding Loaded}" Width="105" />
                     <GridViewColumn Header="Domain Roaming" DisplayMemberBinding="{Binding RoamingConfigured}" Width="105"/>
                     <GridViewColumn Header="Local Admin" DisplayMemberBinding="{Binding IsLocalAdmin}" Width="105"/>
                     <GridViewColumn Header="Local Path" DisplayMemberBinding="{Binding LocalPath}" Width="140"/>
                     <GridViewColumn Header="Local Profile Size" DisplayMemberBinding="{Binding LocalProfileSize}" Width="105"/>
                 </GridView>
             </ListView.View>
         </ListView>
         <GroupBox Header="System Migration Options"  Height="155" Width="430" FontWeight="Bold" Grid.ColumnSpan="4" HorizontalAlignment="Left" Margin="7,351,0,-481">
             <Grid HorizontalAlignment="Left" Height="137" Margin="2,0,0,0" VerticalAlignment="Center" Width="423">
                 <Label Content="JumpCloud Connect Key :" HorizontalAlignment="Left" Margin="3,8,0,0" VerticalAlignment="Top" AutomationProperties.HelpText="https://console.jumpcloud.com/#/systems/new" ToolTip="https://console.jumpcloud.com/#/systems/new" FontWeight="Normal"/>
                 <TextBox Name="tbJumpCloudConnectKey" HorizontalAlignment="Left" Height="23" Margin="149,10,0,0" TextWrapping="Wrap" Text="Enter JumpCloud Connect Key" VerticalAlignment="Top" Width="263" Background="#FFC6CBCF" FontWeight="Bold" IsEnabled="False"/>
                 <CheckBox Name="cb_installjcagent" Content="Install JCAgent" HorizontalAlignment="Left" Margin="123,88,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                 <CheckBox Name="cb_leavedomain" Content="Leave Domain" HorizontalAlignment="Left" Margin="10,108,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                 <CheckBox Name="cb_forcereboot" Content="Force Reboot" HorizontalAlignment="Left" Margin="10,88,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                 <CheckBox Name="cb_verbose" Content="Verbose" HorizontalAlignment="Left" Margin="249,88,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                 <Label Content="JumpCloud API Key :" HorizontalAlignment="Left" Margin="4,37,0,0" VerticalAlignment="Top" AutomationProperties.HelpText="https://console.jumpcloud.com/" ToolTip="https://console.jumpcloud.com/" FontWeight="Normal"/>
                 <TextBox Name="tbJumpCloudAPIKey" HorizontalAlignment="Left" Height="23" Margin="149,39,0,0" TextWrapping="Wrap" Text="Enter JumpCloud API Key" VerticalAlignment="Top" Width="263" Background="#FFC6CBCF" FontWeight="Bold" IsEnabled="False"/>
                 <CheckBox Name="cb_autobindjcuser" Content="Autobind JC User" HorizontalAlignment="Left" Margin="123,111,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
             </Grid>
         </GroupBox>
         <GroupBox Header="Account Migration Information" Height="92" FontWeight="Bold" Grid.ColumnSpan="3" Margin="228,351,9,-418" Grid.Column="1">
             <Grid HorizontalAlignment="Left" Height="66.859" Margin="1.212,2.564,0,0" VerticalAlignment="Top" Width="454.842">
                 <Grid.ColumnDefinitions>
                     <ColumnDefinition Width="23*"/>
                     <ColumnDefinition Width="432*"/>
                 </Grid.ColumnDefinitions>
                 <Label Content="Local Account Username :" HorizontalAlignment="Left" Margin="0,8,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.ColumnSpan="2"/>
                 <Label Content="Local Account Password :" HorizontalAlignment="Left" Margin="0,36,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.ColumnSpan="2"/>
                 <TextBox Name="tbJumpCloudUserName" HorizontalAlignment="Left" Height="23" Margin="127,10,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="282" Text="Username should match JumpCloud username" Background="#FFC6CBCF" FontWeight="Bold" Grid.Column="1" />
                 <TextBox Name="tbTempPassword" HorizontalAlignment="Left" Height="23" Margin="128,39,0,0" TextWrapping="Wrap" Text="Temp123!Temp123!" VerticalAlignment="Top" Width="200" FontWeight="Normal" Grid.Column="1"/>
             </Grid>
         </GroupBox>
         <Button Name="bDeleteProfile" Content="Select Profile" Height="23" IsEnabled="False" Grid.ColumnSpan="2" Grid.Column="6" Margin="96,463,9,-461">
             <Button.Effect>
                 <DropShadowEffect/>
             </Button.Effect>
         </Button>
         <GroupBox Header="System Information" Margin="110,40,9,-140" Width="570" FontWeight="Bold" Grid.Column="1" Grid.ColumnSpan="3">
             <Grid>
                 <Grid.RowDefinitions>
                     <RowDefinition Height="25"/>
                     <RowDefinition Height="25"/>
                     <RowDefinition Height="25"/>
                     <RowDefinition Height="25"/>
                 </Grid.RowDefinitions>
                 <Grid.ColumnDefinitions>
                     <ColumnDefinition/>
                     <ColumnDefinition/>
                     <ColumnDefinition/>
                     <ColumnDefinition/>
                 </Grid.ColumnDefinitions>
                 <Label Content="Computer Name:" FontWeight="Normal" Grid.Column="0" Grid.Row="0"/>
                 <Label Content="Domain Name:" FontWeight="Normal" Grid.Column="0" Grid.Row="1"/>
                 <Label Content="NetBios Name:" FontWeight="Normal" Grid.Column="0" Grid.Row="2"/>
                 <Label Content="Secure Channel Healthy:" FontWeight="Normal" Grid.Column="0" Grid.Row="3"/>
                 <Label Name="lbComputerName" Content="" FontWeight="Normal" Grid.Column="1" Grid.Row="0"/>
                 <Label Name="lbDomainName" Content="" FontWeight="Normal" Grid.Column="1" Grid.Row="1"/>
                 <Label Name="lbNetBios" Content="" FontWeight="Normal" Grid.Column="1" Grid.Row="2"/>
                 <Label Name="lbsecurechannel" Content="" FontWeight="Normal" Grid.Column="1" Grid.Row="3"/>
                 <Label Content="AzureAD Joined:" FontWeight="Normal" Grid.Column="2" Grid.Row="0"/>
                 <Label Content="Workplace Joined:" FontWeight="Normal" Grid.Column="2" Grid.Row="1"/>
                 <Label Content="Azure Tenant Name:" FontWeight="Normal" Grid.Column="2" Grid.Row="2"/>
                 <Label Name="lbAzureAD_Joined" Content="" FontWeight="Normal" Grid.Column="3" Grid.Row="0"/>
                 <Label Name="lbWorkplace_Joined" Content="" FontWeight="Normal" Grid.Column="3" Grid.Row="1"/>
                 <Label Name="lbTenantName" Content="" FontWeight="Normal" Grid.Column="3" Grid.Row="2"/>
             </Grid>
         </GroupBox>
     </Grid>
     <Button Name="btn_close" Content="X" Grid.Column="1" HorizontalAlignment="Left" Margin="436,0,0,0" VerticalAlignment="Center" Width="24" Height="25"/>
 </Grid>
       </Window>
'@
# Read XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
Try
{
    $Form = [Windows.Markup.XamlReader]::Load($reader)
}
Catch
{
    Write-Error "Unable to load Windows.Markup.XamlReader. Some possible causes for this problem include: .NET Framework is missing PowerShell must be launched with PowerShell -sta, invalid XAML code was encountered.";
    Exit;
}
#===========================================================================
# Store Form Objects In PowerShell
#===========================================================================
$xaml.SelectNodes("//*[@Name]") | ForEach-Object { Set-Variable -Name ($_.Name) -Value $Form.FindName($_.Name) }
# Define misc static variables
        $WmiComputerSystem = Get-WmiObject -Class:('Win32_ComputerSystem')
        Write-progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Checking AzureAD Status..' -PercentComplete 25
        Write-Log 'Loading Jumpcloud ADMU. Please Wait.. Checking AzureAD Status..'
        if ($WmiComputerSystem.PartOfDomain) {
            $WmiComputerDomain = Get-WmiObject -Class:('Win32_ntDomain')
            $securechannelstatus = Test-ComputerSecureChannel
            $nbtstat = nbtstat -n
            foreach ($line in $nbtStat)
            {
                if ($line -match '^\s*([^<\s]+)\s*<00>\s*GROUP')
                {
                    $NetBiosName = $matches[1]
                }
            }
            if([System.String]::IsNullOrEmpty($WmiComputerDomain[0].DnsForestName) -and $securechannelstatus -eq $false)
            {
                $DomainName = 'Fix Secure Channel'
            } else {
                $DomainName = [string]$WmiComputerDomain.DnsForestName
            }
                $NetBiosName = [string]$NetBiosName
        }
        elseif ($WmiComputerSystem.PartOfDomain -eq $false) {
            $DomainName = 'N/A'
            $NetBiosName = 'N/A'
            $securechannelstatus = 'N/A'
        }
        if ((Get-CimInstance Win32_OperatingSystem).Version -match '10') {
            $AzureADInfo = dsregcmd.exe /status
            foreach ($line in $AzureADInfo) {
                if ($line -match "AzureADJoined : ") {
                    $AzureADStatus = ($line.trimstart('AzureADJoined : '))
                }
                if ($line -match "WorkplaceJoined : ") {
                    $Workplace_join = ($line.trimstart('WorkplaceJoined : '))
                }
                if ($line -match "TenantName : ") {
                    $TenantName = ($line.trimstart('WorkplaceTenantName : '))
                }
            }
        }
        else {
            $AzureADStatus = 'N/A'
            $Workplace_join = 'N/A'
            $TenantName = 'N/A'
        }
        $FormResults = [PSCustomObject]@{ }
        Write-Progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Verifying Local Accounts & Group Membership..' -PercentComplete 50
        Write-Log 'Loading Jumpcloud ADMU. Please Wait.. Verifying Local Accounts & Group Membership..'
        Write-Progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Getting C:\ & Local Profile Data..' -PercentComplete 70
        Write-Log 'Loading Jumpcloud ADMU. Please Wait.. Getting C:\ & Local Profile Data..'
        # Get Valid SIDs from the Registry and build user object
        $registyProfiles = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
        $profileList = @()
        foreach ($profile in $registyProfiles) {
            $profileList += Get-ItemProperty -Path $profile.PSPath | Select-Object PSChildName, ProfileImagePath
        }
        # List to store users
        $users = @()
        foreach ($listItem in $profileList) {
            $sidPattern = "^S-\d-\d+-(\d+-){1,14}\d+$"
            $isValidFormat = [regex]::IsMatch($($listItem.PSChildName), $sidPattern);
            # Get Valid SIDs
            if ($isValidFormat) {
                # Populate Users List
                $users += [PSCustomObject]@{
                    Name              = ConvertSID $listItem.PSChildName
                    LocalPath         = $listItem.ProfileImagePath
                    SID               = $listItem.PSChildName
                    IsLocalAdmin      = $null
                    LocalProfileSize  = $null
                    Loaded            = $null
                    RoamingConfigured = $null
                    LastLogin         = $null
                }
            }
        }
        # Get Win32 Profiles to merge data with valid SIDs
        $win32UserProfiles = Get-WmiObject -Class:('Win32_UserProfile') -Property * | Where-Object { $_.Special -eq $false }
        $date_format = "yyyy-MM-dd HH:mm"
        foreach ($user in $users) {
            # Get Data from Win32Profile
            foreach ($win32user in $win32UserProfiles) {
                if ($($user.SID) -eq $($win32user.SID)) {
                    $user.RoamingConfigured = $win32user.RoamingConfigured
                    $user.Loaded = $win32user.Loaded
                    if ([string]::IsNullOrEmpty($($win32user.LastUseTime))){
                        $user.LastLogin = "N/A"
                    }
                    else{
                        $user.LastLogin = [System.Management.ManagementDateTimeConverter]::ToDateTime($($win32user.LastUseTime)).ToUniversalTime().ToSTring($date_format)
                    }
                }
            }
            # Get Admin Status
            try {
                $admin = Get-LocalGroupMember -Member "$($user.SID)" -Name "Administrators" -EA SilentlyContinue
            }
            catch {
                $user = Get-LocalGroupMember -Member "$($user.SID)" -Name "Users"
            }
            if ($admin) {
                $user.IsLocalAdmin = $true
            }
            else {
                $user.IsLocalAdmin = $false
            }
            # Get Profile Size
            $largeprofile = Get-ChildItem $($user.LocalPath) -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Sum length | Select-Object -ExpandProperty Sum
            $largeprofile = [math]::Round($largeprofile / 1MB, 0)
            $user.LocalProfileSize = $largeprofile
        }
        Write-Progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Building Profile Group Box Query..' -PercentComplete 85
        Write-Log 'Loading Jumpcloud ADMU. Please Wait.. Building Profile Group Box Query..'
        $Profiles = $users | Select-Object SID, RoamingConfigured, Loaded, IsLocalAdmin, LocalPath, LocalProfileSize, LastLogin, @{Name = "UserName"; EXPRESSION = { $_.Name } }
        Write-Progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Done!' -PercentComplete 100
        Write-Log 'Loading Jumpcloud ADMU. Please Wait.. Done!'
#load UI Labels
#SystemInformation
$lbComputerName.Content = $WmiComputerSystem.Name
#DomainInformation
$lbDomainName.Content = $DomainName
$lbNetBios.Content = $NetBiosName
$lbsecurechannel.Content = $securechannelstatus
#AzureADInformation
$lbAzureAD_Joined.Content = $AzureADStatus
$lbWorkplace_Joined.Content = $Workplace_join
$lbTenantName.Content = $TenantName
Function Test-Button([object]$tbJumpCloudUserName, [object]$tbJumpCloudConnectKey, [object]$tbTempPassword, [object]$lvProfileList, [object]$tbJumpCloudAPIKey)
{
    If (![System.String]::IsNullOrEmpty($lvProfileList.SelectedItem.UserName))
    {
        If (!(Test-IsNotEmpty $tbJumpCloudUserName.Text) -and (Test-HasNoSpaces $tbJumpCloudUserName.Text) `
                -and ((Test-Is40chars $tbJumpCloudConnectKey.Text) -and (Test-HasNoSpaces $tbJumpCloudConnectKey.Text) -and ($cb_installjcagent.IsChecked -eq $true))`
                -and ((Test-Is40chars $tbJumpCloudAPIKey.Text) -and (Test-HasNoSpaces $tbJumpCloudAPIKey.Text) -and ($cb_autobindjcuser.IsChecked -eq $true))`
                -and !(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpaces $tbTempPassword.Text)`
                -and !($lvProfileList.selectedItem.Username -match $WmiComputerSystem.Name)`
                -and !(Test-Localusername $tbJumpCloudUserName.Text))
        {
            $script:bDeleteProfile.Content = "Migrate Profile"
            $script:bDeleteProfile.IsEnabled = $true
            Return $true
        }
        ElseIf (!(Test-IsNotEmpty $tbJumpCloudUserName.Text) -and (Test-HasNoSpaces $tbJumpCloudUserName.Text) `
                -and ((Test-Is40chars $tbJumpCloudConnectKey.Text) -and (Test-HasNoSpaces $tbJumpCloudConnectKey.Text) -and ($cb_installjcagent.IsChecked -eq $true) -and ($cb_autobindjcuser.IsChecked -eq $false))`
                -and !(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpaces $tbTempPassword.Text)`
                -and !($lvProfileList.selectedItem.Username -match $WmiComputerSystem.Name)`
                -and !(Test-Localusername $tbJumpCloudUserName.Text))
        {
            $script:bDeleteProfile.Content = "Migrate Profile"
            $script:bDeleteProfile.IsEnabled = $true
            Return $true
        }
        ElseIf (!(Test-IsNotEmpty $tbJumpCloudUserName.Text) -and (Test-HasNoSpaces $tbJumpCloudUserName.Text) `
                -and ((Test-Is40chars $tbJumpCloudAPIKey.Text) -and (Test-HasNoSpaces $tbJumpCloudAPIKey.Text) -and ($cb_autobindjcuser.IsChecked -eq $true) -and ($cb_installjcagent.IsChecked -eq $false))`
                -and !(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpaces $tbTempPassword.Text)`
                -and !($lvProfileList.selectedItem.Username -match $WmiComputerSystem.Name)`
                -and !(Test-Localusername $tbJumpCloudUserName.Text))
        {
            $script:bDeleteProfile.Content = "Migrate Profile"
            $script:bDeleteProfile.IsEnabled = $true
            Return $true
        }
        Elseif(!(Test-IsNotEmpty $tbJumpCloudUserName.Text) -and (Test-HasNoSpaces $tbJumpCloudUserName.Text) `
        -and ($cb_installjcagent.IsChecked -eq $false) -and ($cb_autobindjcuser.IsChecked -eq $false)`
        -and !(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpaces $tbTempPassword.Text)`
        -and !($lvProfileList.selectedItem.Username -match $WmiComputerSystem.Name)`
        -and !(Test-Localusername $tbJumpCloudUserName.Text))
        {
            $script:bDeleteProfile.Content = "Migrate Profile"
            $script:bDeleteProfile.IsEnabled = $true
            Return $true
        }
        Elseif(($lvProfileList.selectedItem.Username -match $WmiComputerSystem.Name) -or ($lvProfileList.selectedItem.Username -eq 'UNKNOWN ACCOUNT')){
            $script:bDeleteProfile.Content = "Select Domain Profile"
            $script:bDeleteProfile.IsEnabled = $false
            Return $false
        }
        Else
        {
            $script:bDeleteProfile.Content = "Correct Errors"
            $script:bDeleteProfile.IsEnabled = $false
            Return $false
        }
    }
    Else
    {
        $script:bDeleteProfile.Content = "Select Profile"
        $script:bDeleteProfile.IsEnabled = $false
        Return $false
    }
}
## Form changes & interactions
# Verbose checkbox
$cb_verbose.Add_Checked({$VerbosePreference = 'Continue'})
# Install JCAgent checkbox
$script:InstallJCAgent = $false
$cb_installjcagent.Add_Checked({Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)})
$cb_installjcagent.Add_Checked({$script:InstallJCAgent = $true})
$cb_installjcagent.Add_Checked({$tbJumpCloudConnectKey.IsEnabled =$true})
$cb_installjcagent.Add_UnChecked({Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)})
$cb_installjcagent.Add_Unchecked({$script:InstallJCAgent = $false})
$cb_installjcagent.Add_Unchecked({$tbJumpCloudConnectKey.IsEnabled =$false})
# Autobind JC User checkbox
$script:AutobindJCUser = $false
$cb_autobindjcuser.Add_Checked({Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)})
$cb_autobindjcuser.Add_Checked({$script:AutobindJCUser = $true})
$cb_autobindjcuser.Add_Checked({$tbJumpCloudAPIKey.IsEnabled =$true})
$cb_autobindjcuser.Add_UnChecked({Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)})
$cb_autobindjcuser.Add_Unchecked({$script:AutobindJCUser = $false})
$cb_autobindjcuser.Add_Unchecked({$tbJumpCloudAPIKey.IsEnabled =$false})
# Leave Domain checkbox
$script:LeaveDomain = $false
$cb_leavedomain.Add_Checked({$script:LeaveDomain = $true})
$cb_leavedomain.Add_Unchecked({$script:LeaveDomain = $false})
# Force Reboot checkbox
$script:ForceReboot = $false
$cb_forcereboot.Add_Checked({$script:ForceReboot = $true})
$cb_forcereboot.Add_Unchecked({$script:ForceReboot = $false})
$tbJumpCloudUserName.add_TextChanged( {
        Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
        If ((Test-IsNotEmpty $tbJumpCloudUserName.Text) -or (!(Test-HasNoSpaces $tbJumpCloudUserName.Text)) -or (Test-Localusername $tbJumpCloudUserName.Text))
        {
            $tbJumpCloudUserName.Background = "#FFC6CBCF"
            $tbJumpCloudUserName.Tooltip = "Local account user name can not be empty, contain spaces or already exist on the local system."
        }
        Else
        {
            $tbJumpCloudUserName.Background = "white"
            $tbJumpCloudUserName.Tooltip = $null
            $tbJumpCloudUserName.FontWeight = "Normal"
        }
    })
$tbJumpCloudUserName.add_GotFocus( {
        $tbJumpCloudUserName.Text = ""
    })
$tbJumpCloudConnectKey.add_TextChanged( {
        Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
        If (((Test-Is40chars $tbJumpCloudConnectKey.Text) -and (Test-HasNoSpaces $tbJumpCloudConnectKey.Text)) -eq $false)
        {
            $tbJumpCloudConnectKey.Background = "#FFC6CBCF"
            $tbJumpCloudConnectKey.Tooltip = "Connect Key Must be 40chars & Not Contain Spaces"
        }
        Else
        {
            $tbJumpCloudConnectKey.Background = "white"
            $tbJumpCloudConnectKey.Tooltip = $null
            $tbJumpCloudConnectKey.FontWeight = "Normal"
        }
    })
$tbJumpCloudAPIKey.add_TextChanged( {
    Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbJumpCloudConnectAPIKey:($tbJumpCloudAPIKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
    If (((Test-Is40chars $tbJumpCloudAPIKey.Text) -and (Test-HasNoSpaces $tbJumpCloudAPIKey.Text)) -eq $false)
    {
        $tbJumpCloudAPIKey.Background = "#FFC6CBCF"
        $tbJumpCloudAPIKey.Tooltip = "API Key Must be 40chars & Not Contain Spaces"
    }
    Else
    {
        $tbJumpCloudAPIKey.Background = "white"
        $tbJumpCloudAPIKey.Tooltip = $null
        $tbJumpCloudAPIKey.FontWeight = "Normal"
    }
})
$tbJumpCloudConnectKey.add_GotFocus( {
    $tbJumpCloudConnectKey.Text = ""
    })
$tbJumpCloudAPIKey.add_GotFocus( {
    $tbJumpCloudAPIKey.Text = ""
})
$tbTempPassword.add_TextChanged( {
        Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
        If ((!(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpaces $tbTempPassword.Text)) -eq $false)
        {
            $tbTempPassword.Background = "#FFC6CBCF"
            $tbTempPassword.Tooltip = "Temp Password Must Not Be Empty & Not Contain Spaces"
        }
        Else
        {
            $tbTempPassword.Background = "white"
            $tbTempPassword.Tooltip = $null
            $tbTempPassword.FontWeight = "Normal"
        }
    })
# Change button when profile selected
$lvProfileList.Add_SelectionChanged( {
        $script:SelectedUserName = ($lvProfileList.SelectedItem.username)
        New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS
        Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
            try {
                $SelectedUserSID = ((New-Object System.Security.Principal.NTAccount($script:SelectedUserName)).Translate( [System.Security.Principal.SecurityIdentifier]).Value)
            }
            catch {
                $SelectedUserSID = $script:SelectedUserName
            }
        $hku = ('HKU:\'+$SelectedUserSID)
        if (Test-Path -Path $hku) {
            $script:bDeleteProfile.Content = "User Registry Loaded"
            $script:bDeleteProfile.IsEnabled = $false
            $script:tbJumpCloudUserName.IsEnabled = $false
            $script:tbTempPassword.IsEnabled = $false
        }
        else {
            $script:tbJumpCloudUserName.IsEnabled = $true
            $script:tbTempPassword.IsEnabled = $true
        }
    })
$bDeleteProfile.Add_Click( {
        # Build FormResults object
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('InstallJCAgent') -Value:($InstallJCAgent)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('AutobindJCUser') -Value:($AutobindJCUser)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('LeaveDomain') -Value:($LeaveDomain)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('ForceReboot') -Value:($ForceReboot)
        # Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('DomainUserName') -Value:($SelectedUserName.Substring($SelectedUserName.IndexOf('\') + 1))
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('DomainUserName') -Value:($SelectedUserName)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('JumpCloudUserName') -Value:($tbJumpCloudUserName.Text)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('TempPassword') -Value:($tbTempPassword.Text)
        if(($tbJumpCloudConnectKey.Text).length -eq 40){
            Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('JumpCloudConnectKey') -Value:($tbJumpCloudConnectKey.Text)
        }
        if(($tbJumpCloudAPIKey.Text).length -eq 40){
            Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('JumpCloudAPIKey') -Value:($tbJumpCloudAPIKey.Text)
        }
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('NetBiosName') -Value:($SelectedUserName)
        # Close form
        $Form.Close()
    })
# JCConsole Link
$tbjcconsole.Add_PreviewMouseDown( { [System.Diagnostics.Process]::start('https://console.jumpcloud.com/login') })
# JCADMUGH Link
$tbjcadmugh.Add_PreviewMouseDown( { [System.Diagnostics.Process]::start('https://github.com/TheJumpCloud/jumpcloud-ADMU') })
# JCSupport Link
$tbjcsupport.Add_PreviewMouseDown( { [System.Diagnostics.Process]::start('https://support.jumpcloud.com/support/s/') })
# jcadmulog
$tbjcadmulog.Add_PreviewMouseDown( { Invoke-Item "C:\Windows\Temp\JCADMU.log" })
# close button
$btn_close.Add_Click( {
    $Form.Close()
})
# move window
$Form.Add_MouseLeftButtonDown({
    $Form.DragMove()
})
# Put the list of profiles in the profile box
$Profiles | ForEach-Object { $lvProfileList.Items.Add($_) | Out-Null }
#===========================================================================
# Shows the form & allow move
#===========================================================================
$Form.Showdialog()
If ($bDeleteProfile.IsEnabled -eq $true)
{
# Send form results to process if $formresults & securechannel true
If (-not [System.String]::IsNullOrEmpty($formResults))
{
    Start-Migration -inputObject:($formResults)
}
Else
{
    Write-Output ('Exiting ADMU process')
}
}
