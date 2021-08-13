Write-ToLog 'Loading Jumpcloud ADMU. Please Wait.. Loading ADMU GUI..'

#==============================================================================================
# XAML Code - Imported from Visual Studio WPF Application
#==============================================================================================
[void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')
[xml]$XAML = @'
<Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="JumpCloud ADMU 2.0.0" Height="629" Width="1000"
        WindowStyle="SingleBorderWindow"
        ResizeMode="NoResize"
        Background="White">

    <Grid Margin="10,10,10,10">
        <Grid.RowDefinitions>
            <RowDefinition Height="25"/>
            <RowDefinition/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
        </Grid.ColumnDefinitions>
        <Grid Row="0"
              Grid.ColumnSpan="1"/>
        <ListView Name="lvProfileList" Margin="10,223,10,188" Grid.Row="1">
            <ListView.View>
                <GridView>
                    <GridViewColumn Header="System Accounts" DisplayMemberBinding="{Binding UserName}" Width="300"/>
                    <GridViewColumn Header="Last Login" DisplayMemberBinding="{Binding LastLogin}" Width="135"/>
                    <GridViewColumn Header="Currently Active" DisplayMemberBinding="{Binding Loaded}" Width="145" />
                    <GridViewColumn Header="Local Admin" DisplayMemberBinding="{Binding IsLocalAdmin}" Width="115"/>
                    <GridViewColumn Header="Local Path" DisplayMemberBinding="{Binding LocalPath}" Width="225"/>
                </GridView>
            </ListView.View>
        </ListView>
        <GroupBox Header="System Migration Options" Width="485" FontWeight="Bold" HorizontalAlignment="Left" Margin="0,395,0,0" Grid.Row="1">
            <Grid HorizontalAlignment="Left" Height="139" Margin="10,0,0,0" VerticalAlignment="Center" Width="465">

                <Label Name="lbl_connectkey" Content="JumpCloud Connect Key :" HorizontalAlignment="Left" Margin="3,6,0,0" VerticalAlignment="Top" FontWeight="Normal" />
                <TextBox Name="tbJumpCloudConnectKey" HorizontalAlignment="Left" Height="23" Margin="167,10,0,0" Text="Enter JumpCloud Connect Key" VerticalAlignment="Top" Width="271" Background="#FFC6CBCF" FontWeight="Bold" IsEnabled="False"/>
                <CheckBox Name="cb_installjcagent" Content="Install JCAgent" HorizontalAlignment="Left" Margin="123,76,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                <CheckBox Name="cb_leavedomain" Content="Leave Domain" HorizontalAlignment="Left" Margin="10,98,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                <CheckBox Name="cb_forcereboot" Content="Force Reboot" HorizontalAlignment="Left" Margin="10,76,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                <Label Name="lbl_apikey" Content="JumpCloud API Key :" HorizontalAlignment="Left" Margin="3,36,0,0" VerticalAlignment="Top" AutomationProperties.HelpText="https://console.jumpcloud.com/" ToolTip="https://console.jumpcloud.com/" FontWeight="Normal" />
                <TextBox Name="tbJumpCloudAPIKey" HorizontalAlignment="Left" Height="23" Margin="167,40,0,0" Text="Enter JumpCloud API Key" VerticalAlignment="Top" Width="271" Background="#FFC6CBCF" FontWeight="Bold" IsEnabled="False"/>
                <CheckBox Name="cb_autobindjcuser" Content="Autobind JC User" HorizontalAlignment="Left" Margin="123,98,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                <Image Name="img_ckey_info" HorizontalAlignment="Left" Height="19" Margin="148,11,0,0" VerticalAlignment="Top" Width="19" Source="https://i.ibb.co/1L0CRCh/info.png" Visibility="Hidden" ToolTip="https://console.jumpcloud.com/" />
                <Image Name="img_ckey_valid" HorizontalAlignment="Left" Height="19" Margin="443,12,0,0" VerticalAlignment="Top" Width="19" Source="https://i.ibb.co/rfjgc8h/error.png" Visibility="Hidden" ToolTip="Connect Key must be 40chars &amp; not contain spaces" />
                <Image Name="img_apikey_info" HorizontalAlignment="Left" Height="19" Margin="148,41,0,0" VerticalAlignment="Top" Width="19" Source="https://i.ibb.co/1L0CRCh/info.png" Visibility="Hidden" ToolTip="https://console.jumpcloud.com/" />
                <Image Name="img_apikey_valid" HorizontalAlignment="Left" Height="19" Margin="443,41,0,0" VerticalAlignment="Top" Width="19" Source="https://i.ibb.co/rfjgc8h/error.png" Visibility="Hidden" ToolTip="Correct error" />

            </Grid>
        </GroupBox>
        <GroupBox Header="Account Migration Information" FontWeight="Bold" Margin="490,395,10,58" Grid.Row="1">
            <Grid HorizontalAlignment="Left" Height="66" Margin="1,0,0,0" VerticalAlignment="Top" Width="461">
                <Label Content="Local Account Username :" HorizontalAlignment="Left" Margin="0,8,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.ColumnSpan="2"/>
                <Label Content="Local Account Password :" HorizontalAlignment="Left" Margin="0,36,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.ColumnSpan="2"/>
                <TextBox Name="tbJumpCloudUserName" HorizontalAlignment="Left" Height="23" Margin="192,10,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="235" Text="Username should match JumpCloud username" Background="#FFC6CBCF" FontWeight="Bold" />
                <TextBox Name="tbTempPassword" HorizontalAlignment="Left" Height="23" Margin="192,38,0,0" TextWrapping="Wrap" Text="Temp123!Temp123!" VerticalAlignment="Top" Width="235" FontWeight="Normal"/>
                <Image Name="img_localaccount_info" HorizontalAlignment="Left" Height="19" Margin="169,11,0,0" VerticalAlignment="Top" Width="19" Source="https://i.ibb.co/1L0CRCh/info.png" Visibility="Visible"/>
                <Image Name="img_localaccount_valid" HorizontalAlignment="Left" Height="19" Margin="432,12,0,0" VerticalAlignment="Top" Width="19" Source="https://i.ibb.co/rfjgc8h/error.png" ToolTip="Local account username can't be empty, contain spaces, already exist on the local system or match the local computer name." Visibility="Visible" />
                <Image Name="img_localaccount_password_info" HorizontalAlignment="Left" Height="19" Margin="169,40,0,0" VerticalAlignment="Top" Width="19" Source="https://i.ibb.co/1L0CRCh/info.png" Visibility="Visible"/>
                <Image Name="img_localaccount_password_valid" HorizontalAlignment="Left" Height="19" Margin="432,40,0,0" VerticalAlignment="Top" Width="19" Source="https://i.ibb.co/dJyG1q5/check.png" Visibility="Visible"/>
            </Grid>
        </GroupBox>
        <GroupBox Header="System Information" FontWeight="Bold" Margin="397,108,10,350" Grid.Row="1">
            <Grid HorizontalAlignment="Left" Height="80" Margin="10,0,0,0" VerticalAlignment="Center" Width="594">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="125"/>
                    <ColumnDefinition Width="125"/>
                    <ColumnDefinition Width="125*"/>
                    <ColumnDefinition Width="125*"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition Height="25"/>
                    <RowDefinition Height="25"/>
                    <RowDefinition Height="25"/>
                </Grid.RowDefinitions>
                <Label Content="Computer Name:" HorizontalAlignment="Left" Margin="0,0,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.Column="0" Grid.ColumnSpan="1" Grid.Row="0" />
                <Label Content="Domain Name:" HorizontalAlignment="Left" Margin="0,0,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.Column="0" Grid.ColumnSpan="1" Grid.Row="1" />
                <Label Content="NetBios Name:" HorizontalAlignment="Left" Margin="0,0,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.Column="0" Grid.ColumnSpan="1" Grid.Row="2" />
                <Label Content="AzureAD Joined:" HorizontalAlignment="Left" Margin="0,0,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.Column="2" Grid.ColumnSpan="1" Grid.Row="0" />
                <Label Content="Tenant Name:" HorizontalAlignment="Left" Margin="0,0,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.Column="2" Grid.ColumnSpan="1" Grid.Row="1"/>
                <Label Name="lbTenantName" Content="" FontWeight="Normal" Grid.Column="3" Grid.Row="1"/>
                <Label Name="lbAzureAD_Joined" Content="" FontWeight="Normal" Grid.Column="3" Grid.Row="0"/>
                <Label Name="lbComputerName" Content="" FontWeight="Normal" Grid.Column="1" Grid.Row="0"/>
                <Label Name="lbDomainName" Content="" FontWeight="Normal" Grid.Column="1" Grid.Row="1"/>
                <Label Name="lbNetBios" Content="" FontWeight="Normal" Grid.Column="1" Grid.Row="2"/>

            </Grid>
        </GroupBox>
        <Image
            Source="https://jumpcloud.com/wp-content/themes/jumpcloud/assets/images/jumpcloud-press-kit/logos/01-combination-mark-color.png" Margin="3,0,749,537" Grid.RowSpan="2"/>
        <Button Name="bDeleteProfile" Content="Select Profile" HorizontalAlignment="Left" Margin="590,515,0,0" Grid.Row="1" VerticalAlignment="Top" Width="146" Height="24"/>

        <GroupBox Header="Migration Steps" HorizontalAlignment="Left" Height="98" Margin="397,5,0,0" VerticalAlignment="Top" Width="573" FontWeight="Bold" Grid.Row="1">
            <TextBlock HorizontalAlignment="Left" TextWrapping="Wrap" VerticalAlignment="Top" Height="70" Width="561" FontWeight="Normal"><Run Text="1. Select the domain or AzureAD account that you want to migrate to a local account from the list below."/><LineBreak/><Run Text="2. Enter a local account username and password to migrate the selected account to. "/><LineBreak/><Run Text="3. Enter your organizations JumpCloud system connect key."/><LineBreak/><Run Text="4. Click the "/><Run Text="Migrate Profile"/><Run Text=" button."/><LineBreak/><Run/></TextBlock>
        </GroupBox>

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
Write-ToLog 'Loading Jumpcloud ADMU. Please Wait.. Checking AzureAD Status..'
if ($WmiComputerSystem.PartOfDomain)
{
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

    if ([System.String]::IsNullOrEmpty($WmiComputerDomain[0].DnsForestName) -and $securechannelstatus -eq $false)
    {
        $DomainName = 'Fix Secure Channel'
    }
    else
    {
        $DomainName = [string]$WmiComputerDomain.DnsForestName
    }
    $NetBiosName = [string]$NetBiosName
}
elseif ($WmiComputerSystem.PartOfDomain -eq $false)
{
    $DomainName = 'N/A'
    $NetBiosName = 'N/A'
    $securechannelstatus = 'N/A'
}
if ((Get-CimInstance Win32_OperatingSystem).Version -match '10')
{
    $AzureADInfo = dsregcmd.exe /status
    foreach ($line in $AzureADInfo)
    {
        if ($line -match "AzureADJoined : ")
        {
            $AzureADStatus = ($line.trimstart('AzureADJoined : '))
        }
        if ($line -match "WorkplaceJoined : ")
        {
            $Workplace_join = ($line.trimstart('WorkplaceJoined : '))
        }
        if ($line -match "TenantName : ")
        {
            $TenantName = ($line.trimstart('WorkplaceTenantName : '))
        }
    }
}
else
{
    $AzureADStatus = 'N/A'
    $Workplace_join = 'N/A'
    $TenantName = 'N/A'
}

$FormResults = [PSCustomObject]@{ }
Write-Progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Verifying Local Accounts & Group Membership..' -PercentComplete 50
Write-ToLog 'Loading Jumpcloud ADMU. Please Wait.. Verifying Local Accounts & Group Membership..'
Write-Progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Getting C:\ & Local Profile Data..' -PercentComplete 70
Write-ToLog 'Loading Jumpcloud ADMU. Please Wait.. Getting C:\ & Local Profile Data..'
# Get Valid SIDs from the Registry and build user object
$registyProfiles = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
$profileList = @()
foreach ($profile in $registyProfiles)
{
    $profileList += Get-ItemProperty -Path $profile.PSPath | Select-Object PSChildName, ProfileImagePath
}
# List to store users
$users = @()
foreach ($listItem in $profileList)
{
    $sidPattern = "^S-\d-\d+-(\d+-){1,14}\d+$"
    $isValidFormat = [regex]::IsMatch($($listItem.PSChildName), $sidPattern);
    # Get Valid SIDs
    if ($isValidFormat)
    {
        # Populate Users List
        $users += [PSCustomObject]@{
            Name              = Convert-Sid $listItem.PSChildName
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
foreach ($user in $users)
{
    # Get Data from Win32Profile
    foreach ($win32user in $win32UserProfiles)
    {
        if ($($user.SID) -eq $($win32user.SID))
        {
            $user.RoamingConfigured = $win32user.RoamingConfigured
            $user.Loaded = $win32user.Loaded
            if ([string]::IsNullOrEmpty($($win32user.LastUseTime)))
            {
                $user.LastLogin = "N/A"
            }
            else
            {
                $user.LastLogin = [System.Management.ManagementDateTimeConverter]::ToDateTime($($win32user.LastUseTime)).ToUniversalTime().ToSTring($date_format)
            }
        }
    }
    # Get Admin Status
    try
    {
        $admin = Get-LocalGroupMember -Member "$($user.SID)" -Name "Administrators" -EA SilentlyContinue
    }
    catch
    {
        $user = Get-LocalGroupMember -Member "$($user.SID)" -Name "Users"
    }
    if ($admin)
    {
        $user.IsLocalAdmin = $true
    }
    else
    {
        $user.IsLocalAdmin = $false
    }
    # Get Profile Size
    # $largeprofile = Get-ChildItem $($user.LocalPath) -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Sum length | Select-Object -ExpandProperty Sum
    # $largeprofile = [math]::Round($largeprofile / 1MB, 0)
    # $user.LocalProfileSize = $largeprofile
}

Write-Progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Building Profile Group Box Query..' -PercentComplete 85
Write-ToLog 'Loading Jumpcloud ADMU. Please Wait.. Building Profile Group Box Query..'

$Profiles = $users | Select-Object SID, RoamingConfigured, Loaded, IsLocalAdmin, LocalPath, LocalProfileSize, LastLogin, @{Name = "UserName"; EXPRESSION = { $_.Name } }
Write-Progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Done!' -PercentComplete 100
Write-ToLog 'Loading Jumpcloud ADMU. Please Wait.. Done!'

#load UI Labels

#SystemInformation
$lbComputerName.Content = $WmiComputerSystem.Name

#DomainInformation
$lbDomainName.Content = $DomainName
$lbNetBios.Content = $NetBiosName

#AzureADInformation
$lbAzureAD_Joined.Content = $AzureADStatus
$lbTenantName.Content = $TenantName

Function Test-Button([object]$tbJumpCloudUserName, [object]$tbJumpCloudConnectKey, [object]$tbTempPassword, [object]$lvProfileList, [object]$tbJumpCloudAPIKey)
{
    If (![System.String]::IsNullOrEmpty($lvProfileList.SelectedItem.UserName))
    {
        If (!(Test-IsNotEmpty $tbJumpCloudUserName.Text) -and (Test-HasNoSpace $tbJumpCloudUserName.Text) `
                -and ((Test-Is40chars $tbJumpCloudConnectKey.Text) -and (Test-HasNoSpace $tbJumpCloudConnectKey.Text) -and ($cb_installjcagent.IsChecked -eq $true))`
                -and ((Test-Is40chars $tbJumpCloudAPIKey.Text) -and (Test-HasNoSpace $tbJumpCloudAPIKey.Text) -and ($cb_autobindjcuser.IsChecked -eq $true))`
                -and !(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpace $tbTempPassword.Text)`
                -and !($lvProfileList.selectedItem.Username -match $WmiComputerSystem.Name)`
                -and !(Test-Localusername $tbJumpCloudUserName.Text))
        {
            $script:bDeleteProfile.Content = "Migrate Profile"
            $script:bDeleteProfile.IsEnabled = $true
            Return $true
        }
        ElseIf (!(Test-IsNotEmpty $tbJumpCloudUserName.Text) -and (Test-HasNoSpace $tbJumpCloudUserName.Text) `
                -and ((Test-Is40chars $tbJumpCloudConnectKey.Text) -and (Test-HasNoSpace $tbJumpCloudConnectKey.Text) -and ($cb_installjcagent.IsChecked -eq $true) -and ($cb_autobindjcuser.IsChecked -eq $false))`
                -and !(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpace $tbTempPassword.Text)`
                -and !($lvProfileList.selectedItem.Username -match $WmiComputerSystem.Name)`
                -and !(Test-Localusername $tbJumpCloudUserName.Text))
        {
            $script:bDeleteProfile.Content = "Migrate Profile"
            $script:bDeleteProfile.IsEnabled = $true
            Return $true
        }
        ElseIf (!(Test-IsNotEmpty $tbJumpCloudUserName.Text) -and (Test-HasNoSpace $tbJumpCloudUserName.Text) `
                -and ((Test-Is40chars $tbJumpCloudAPIKey.Text) -and (Test-HasNoSpace $tbJumpCloudAPIKey.Text) -and ($cb_autobindjcuser.IsChecked -eq $true) -and ($cb_installjcagent.IsChecked -eq $false))`
                -and !(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpace $tbTempPassword.Text)`
                -and !($lvProfileList.selectedItem.Username -match $WmiComputerSystem.Name)`
                -and !(Test-Localusername $tbJumpCloudUserName.Text))
        {
            $script:bDeleteProfile.Content = "Migrate Profile"
            $script:bDeleteProfile.IsEnabled = $true
            Return $true
        }
        Elseif (!(Test-IsNotEmpty $tbJumpCloudUserName.Text) -and (Test-HasNoSpace $tbJumpCloudUserName.Text) `
                -and ($cb_installjcagent.IsChecked -eq $false) -and ($cb_autobindjcuser.IsChecked -eq $false)`
                -and !(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpace $tbTempPassword.Text)`
                -and !($lvProfileList.selectedItem.Username -match $WmiComputerSystem.Name)`
                -and !(Test-Localusername $tbJumpCloudUserName.Text))
        {
            $script:bDeleteProfile.Content = "Migrate Profile"
            $script:bDeleteProfile.IsEnabled = $true
            Return $true
        }
        Elseif (($lvProfileList.selectedItem.Username -match $WmiComputerSystem.Name) -or ($lvProfileList.selectedItem.Username -eq 'UNKNOWN ACCOUNT'))
        {
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

# Install JCAgent checkbox
$script:InstallJCAgent = $false
$cb_installjcagent.Add_Checked( { Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey) })
$cb_installjcagent.Add_Checked( { $script:InstallJCAgent = $true })
$cb_installjcagent.Add_Checked( { $tbJumpCloudConnectKey.IsEnabled = $true })
$cb_installjcagent.Add_Checked( { $img_ckey_info.Visibility = 'Visible'})
$cb_installjcagent.Add_Checked( { $img_ckey_valid.Visibility = 'Visible'})
$cb_installjcagent.Add_Checked( {
    Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
    If (((Test-Is40chars $tbJumpCloudConnectKey.Text) -and (Test-HasNoSpace $tbJumpCloudConnectKey.Text)) -eq $false)
    {
        #$tbJumpCloudConnectKey.Tooltip = "Connect Key Must be 40chars & Not Contain Spaces"
        $tbJumpCloudConnectKey.Background = "#FFC6CBCF"
        $tbJumpCloudConnectKey.BorderBrush = "#FFF90000"
    }
    Else
    {
        $tbJumpCloudConnectKey.Background = "white"
        $tbJumpCloudConnectKey.Tooltip = $null
        $tbJumpCloudConnectKey.FontWeight = "Normal"
        $tbJumpCloudConnectKey.BorderBrush = "#FFC6CBCF"
    }

})

$cb_installjcagent.Add_UnChecked( { Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey) })
$cb_installjcagent.Add_Unchecked( { $script:InstallJCAgent = $false })
$cb_installjcagent.Add_Unchecked( { $tbJumpCloudConnectKey.IsEnabled = $false })
$cb_installjcagent.Add_Unchecked( {$img_ckey_info.Visibility = 'Hidden'})
$cb_installjcagent.Add_Unchecked( {$img_ckey_valid.Visibility = 'Hidden'})
$cb_installjcagent.Add_Unchecked( {
    Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
    If (((Test-Is40chars $tbJumpCloudConnectKey.Text) -and (Test-HasNoSpace $tbJumpCloudConnectKey.Text) -or ($cb_installjcagent.IsEnabled)) -eq $false)
    {
        #$tbJumpCloudConnectKey.Tooltip = "Connect Key Must be 40chars & Not Contain Spaces"
        $tbJumpCloudConnectKey.Background = "#FFC6CBCF"
        $tbJumpCloudConnectKey.BorderBrush = "#FFF90000"
    }
    Else
    {
        $tbJumpCloudConnectKey.Background = "white"
        $tbJumpCloudConnectKey.Tooltip = $null
        $tbJumpCloudConnectKey.FontWeight = "Normal"
        $tbJumpCloudConnectKey.BorderBrush = "#FFC6CBCF"
    }
})


# Autobind JC User checkbox
$script:AutobindJCUser = $false
$cb_autobindjcuser.Add_Checked( { Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey) })
$cb_autobindjcuser.Add_Checked( { $script:AutobindJCUser = $true })
$cb_autobindjcuser.Add_Checked( { $tbJumpCloudAPIKey.IsEnabled = $true })
$cb_autobindjcuser.Add_Checked( { $img_apikey_info.Visibility = 'Visible'})
$cb_autobindjcuser.Add_Checked( { $img_apikey_valid.Visibility = 'Visible'})
$cb_autobindjcuser.Add_Checked( {
    Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbJumpCloudConnectAPIKey:($tbJumpCloudAPIKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
    If (((Test-Is40chars $tbJumpCloudAPIKey.Text) -and (Test-HasNoSpace $tbJumpCloudAPIKey.Text)) -eq $false)
    {
        #$tbJumpCloudAPIKey.Tooltip = "API Key Must be 40chars & Not Contain Spaces"
        $tbJumpCloudAPIKey.Background = "#FFC6CBCF"
        $tbJumpCloudAPIKey.BorderBrush = "#FFF90000"
    }
    Else
    {
        $tbJumpCloudAPIKey.Background = "white"
        $tbJumpCloudAPIKey.Tooltip = $null
        $tbJumpCloudAPIKey.FontWeight = "Normal"
        $tbJumpCloudAPIKey.BorderBrush = "#FFC6CBCF"
    }
})


$cb_autobindjcuser.Add_UnChecked( { Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey) })
$cb_autobindjcuser.Add_Unchecked( { $script:AutobindJCUser = $false })
$cb_autobindjcuser.Add_Unchecked( { $tbJumpCloudAPIKey.IsEnabled = $false })
$cb_autobindjcuser.Add_Unchecked( { $img_apikey_info.Visibility = 'Hidden'})
$cb_autobindjcuser.Add_Unchecked( { $img_apikey_valid.Visibility = 'Hidden'})
$cb_autobindjcuser.Add_Unchecked( { 
    Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbJumpCloudConnectAPIKey:($tbJumpCloudAPIKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
    If (((Test-Is40chars $tbJumpCloudAPIKey.Text) -and (Test-HasNoSpace $tbJumpCloudAPIKey.Text) -or ($cb_autobindjcuser.IsEnabled)) -eq $false)
    {
        #$tbJumpCloudAPIKey.Tooltip = "API Key Must be 40chars & Not Contain Spaces"
        $tbJumpCloudAPIKey.Background = "#FFC6CBCF"
        $tbJumpCloudAPIKey.BorderBrush = "#FFF90000"
    }
    Else
    {
        $tbJumpCloudAPIKey.Background = "white"
        $tbJumpCloudAPIKey.Tooltip = $null
        $tbJumpCloudAPIKey.FontWeight = "Normal"
        $tbJumpCloudAPIKey.BorderBrush = "#FFC6CBCF"
    }
})

# Leave Domain checkbox
$script:LeaveDomain = $false
$cb_leavedomain.Add_Checked( { $script:LeaveDomain = $true })
$cb_leavedomain.Add_Unchecked( { $script:LeaveDomain = $false })

# Force Reboot checkbox
$script:ForceReboot = $false
$cb_forcereboot.Add_Checked( { $script:ForceReboot = $true })
$cb_forcereboot.Add_Unchecked( { $script:ForceReboot = $false })

$tbJumpCloudUserName.add_TextChanged( {
        Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
        If ((Test-IsNotEmpty $tbJumpCloudUserName.Text) -or (!(Test-HasNoSpace $tbJumpCloudUserName.Text)) -or (Test-Localusername $tbJumpCloudUserName.Text))
        {
            $tbJumpCloudUserName.Background = "#FFC6CBCF"
            $tbJumpCloudUserName.BorderBrush = "#FFF90000"
            $img_localaccount_valid.Source = "https://i.ibb.co/rfjgc8h/error.png"
            $img_localaccount_valid.ToolTip= "Local account username can't be empty, contain spaces, already exist on the local system or match the local computer name."
        }
        Else
        {
            $tbJumpCloudUserName.Background = "white"
            $tbJumpCloudUserName.FontWeight = "Normal"
            $tbJumpCloudUserName.BorderBrush = "#FFC6CBCF"
            $img_localaccount_valid.Source = "https://i.ibb.co/dJyG1q5/check.png"
            $img_localaccount_valid.ToolTip= $null
        }
    })

$tbJumpCloudConnectKey.add_TextChanged( {
        Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
        If (((Test-Is40chars $tbJumpCloudConnectKey.Text) -and (Test-HasNoSpace $tbJumpCloudConnectKey.Text)) -eq $false)
        {
            $tbJumpCloudConnectKey.Background = "#FFC6CBCF"
            $tbJumpCloudConnectKey.BorderBrush = "#FFF90000"
            $img_ckey_valid.Source = "https://i.ibb.co/rfjgc8h/error.png"
            $img_ckey_valid.ToolTip= "Connect Key must be 40chars & not contain spaces."
        }
        Else
        {
            $tbJumpCloudConnectKey.Background = "white"
            $tbJumpCloudConnectKey.FontWeight = "Normal"
            $tbJumpCloudConnectKey.BorderBrush = "#FFC6CBCF"
            $img_ckey_valid.Source = "https://i.ibb.co/dJyG1q5/check.png"
            $img_ckey_valid.ToolTip= $null
        }
    })

$tbJumpCloudAPIKey.add_TextChanged( {
        Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbJumpCloudConnectAPIKey:($tbJumpCloudAPIKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
        If (((Test-Is40chars $tbJumpCloudAPIKey.Text) -and (Test-HasNoSpace $tbJumpCloudAPIKey.Text)) -eq $false)
        {
            $tbJumpCloudAPIKey.Background = "#FFC6CBCF"
            $tbJumpCloudAPIKey.BorderBrush = "#FFF90000"
            $img_apikey_valid.Source = "https://i.ibb.co/rfjgc8h/error.png"
            $img_apikey_valid.ToolTip= "Jumpcloud API Key must be 40chars & not contain spaces."

        }
        Else
        {
            $tbJumpCloudAPIKey.Background = "white"
            $tbJumpCloudAPIKey.Tooltip = $null
            $tbJumpCloudAPIKey.FontWeight = "Normal"
            $tbJumpCloudAPIKey.BorderBrush = "#FFC6CBCF"
            $img_apikey_valid.Source = "https://i.ibb.co/dJyG1q5/check.png"
            $img_apikey_valid.ToolTip= $null
        }
    })

$tbTempPassword.add_TextChanged( {
        Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
        If ((!(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpace $tbTempPassword.Text)) -eq $false)
        {
            $tbTempPassword.Background = "#FFC6CBCF"
            $tbTempPassword.BorderBrush = "#FFF90000"
            $img_localaccount_password_valid.Source = "https://i.ibb.co/rfjgc8h/error.png"
            $img_localaccount_password_valid.ToolTip= "Local Account Temp Password should not be empty or contain spaces, it should also meet local password policy req. on the system."
        }
        Else
        {
            $tbTempPassword.Background = "white"
            $tbTempPassword.Tooltip = $null
            $tbTempPassword.FontWeight = "Normal"
            $tbTempPassword.BorderBrush = "#FFC6CBCF"
            $img_localaccount_password_valid.Source = "https://i.ibb.co/dJyG1q5/check.png"
            $img_localaccount_password_valid.ToolTip= $null
        }
    })

# Change button when profile selected
$lvProfileList.Add_SelectionChanged( {
        $script:SelectedUserName = ($lvProfileList.SelectedItem.username)
        New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS
        Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
        try
        {
            $SelectedUserSID = ((New-Object System.Security.Principal.NTAccount($script:SelectedUserName)).Translate( [System.Security.Principal.SecurityIdentifier]).Value)
        }
        catch
        {
            $SelectedUserSID = $script:SelectedUserName
        }
        $hku = ('HKU:\' + $SelectedUserSID)
        if (Test-Path -Path $hku)
        {
            $script:bDeleteProfile.Content = "User Registry Loaded"
            $script:bDeleteProfile.IsEnabled = $false
            $script:tbJumpCloudUserName.IsEnabled = $false
            $script:tbTempPassword.IsEnabled = $false
        }
        else
        {
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
        if (($tbJumpCloudConnectKey.Text).length -eq 40)
        {
            Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('JumpCloudConnectKey') -Value:($tbJumpCloudConnectKey.Text)
        }
        if (($tbJumpCloudAPIKey.Text).length -eq 40)
        {
            Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('JumpCloudAPIKey') -Value:($tbJumpCloudAPIKey.Text)
        }
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('NetBiosName') -Value:($SelectedUserName)
        # Close form
        $Form.Close()
    })

$tbJumpCloudUserName.add_GotFocus( {
    $tbJumpCloudUserName.Text = ""
})

$tbJumpCloudConnectKey.add_GotFocus( {
        $tbJumpCloudConnectKey.Text = ""
    })

$tbJumpCloudAPIKey.add_GotFocus( {
        $tbJumpCloudAPIKey.Text = ""
    })

# lbl_connectkey link - Mouse button event
$lbl_connectkey.Add_PreviewMouseDown( { [System.Diagnostics.Process]::start('https://console.jumpcloud.com/#/systems/new') })

# lbl_apikey link - Mouse button event
$lbl_apikey.Add_PreviewMouseDown( { [System.Diagnostics.Process]::start('https://console.jumpcloud.com/#/home') })

# move window
$Form.Add_MouseLeftButtonDown( {
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
    Return $FormResults
}