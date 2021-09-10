# JumpCloud Active Directory Migration Utility

![admu-landging-image](https://github.com/TheJumpCloud/jumpcloud-ADMU/wiki/images/ADMU-landing.png)

The JumpCloud Active Directory Migration Utility (ADMU) is designed to migrate Active Directory or Azure Active Directory accounts to local account for subsequent JumpCloud takeover and management. Active Directory accounts on a system can not be directly taken over by the JumpCloud Agent. Those accounts must first be converted to a local account before the JumpCloud agent can take-over and manage that account on a given system. The ADMU aims to help admins automate the otherwise tedious process of account migration.

To see an example of an account migration view the quick video demo below:

<a href="https://fast.wistia.net/embed/iframe/573eial3qa" rel="ADMU video demo">![admu-video-image](https://github.com/TheJumpCloud/jumpcloud-ADMU/wiki/images/video_background.png)</a>


### Why do I need it?

JumpCloud has the ability to sync and bind to Windows local accounts. However, in migration scenarios where the system is currently bound to active directory or Azure AD, the account can not be taken over. Instead, numerous steps must be taken to prepare and convert the target profile to a state which can be taken over and bound to JumpCloud. The JumpCloud Active Directory Migration Utility automates the otherwise tedious steps to convert AD/ Azure AD profiles to local profiles.

Continue to [Getting Started](https://github.com/TheJumpCloud/jumpcloud-ADMU/wiki/Getting-Started) and the [Wiki](https://github.com/TheJumpCloud/jumpcloud-ADMU/wiki) for further information about the tool and its uses.

### How do I download it?

Check out the [Releases](https://github.com/TheJumpCloud/jumpcloud-ADMU/releases) page for the GUI and PowerShell tool downloads.

### Have questions? feature request? issues?

Please use the github issues tab, email [support@jumpcloud.com](support@jumpcloud.com) or the [feedback form](https://github.com/TheJumpCloud/jumpcloud-ADMU/wiki/feedback-form).
