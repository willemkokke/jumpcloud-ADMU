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
    Return $FormResults
}
