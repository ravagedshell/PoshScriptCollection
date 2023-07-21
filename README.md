# ravagedshell/PoshScriptCollection
Here's a collection of some random PowerShell scripts I've worked on, maybe you'll find them useful.

These were created to help me with varying tasks along the years, unfortunately due to career advancement and company IP/DLP policies, I'm not able to share all of them as I lost access when I left my old employers :(

I'm still finding some here and there on my NAS, so there may be periodic updates. I don't really work in a Win Environement anymore, so I don't anticipate creating too-many new ones, but maybe I'll add to them. I don't think any of these are any newer than 2021/2022, so they may or may not work. Use at your own risk.

# Naming Standard
| Prefix       | Description                                                              |
|--------------|--------------------------------------------------------------------------|
| AD_          | Scripts that interact with Active Directory                              |
| AD_          | Scripts that interact with Azure Active Directory                        |
| AWS_         | Scripts that interact with Amazon Web Services                           |
| AZ_          | Scripts that interact with Azure Services                                |
| MSO_         | Scripts that interact with Microsoft Online (Microsoft/Office 365)       |
| SP_          | Scripts that interact with SharePoint Online                             |
| WIN_         | Scripts that interact primarily with Windows core components             |

# Current Scripts Standard
| File                          | Description                                                                                       |
|-------------------------------|---------------------------------------------------------------------------------------------------|
| AD_HIBPCrossReference.ps1     | Cross-references emails from a HaveIBeenPwned Export to users in Active Directory                 |
| AWS_EC2TagRenaming.ps1        | A simple way to rename tags in AWS EC2 using the AWS PowerShell module                            |
| MSO_AdvancedUtils.ps1         | A collection of functions to simplify common tasks I ran into in Microsoft 365                    |
| MSO_GetMFAStatus.ps1          | A simple script to check MFA configuration for a user in Microsoft 365                            |
| SP_PurgePresHoldLibrary.ps1   | A tool that helps purge preservation hold library to bypass retention settings in SharePoint      |
| WIN_BitLockerActivation.ps1   | A tool that helps silently enable BitLocker on devices (remove user interaction)                  |
| WIN_AdvancedLogging.ps1       | A tool that provides a number of ways to log scripting actions (txt, CSV, Cloudwatch, etc)        |
