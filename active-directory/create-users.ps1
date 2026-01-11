#####
## Global variables
$csvFile = ""
$OUPath = ""
$domainName = ""
#####

# Import-Module ActiveDirectory

$userList = Import-Csv -Path $csvFile

foreach ($User in $userList) {
    New-ADUser @{
        SamAccountName        = $User.username
        UserPrincipalName     = "$($User.username)@$domainName"
        Name                  = "$User.firstname $User.lastname"
        GivenName             = $User.firstname
        Surname               = $User.lastname
        Enabled               = $True
        ChangePasswordAtLogon = $False
        PasswordNeverExpires  = $True
        DisplayName           = "$User.firstname $User.lastname"
        Path                  = $OUPath
        AccountPassword       = (ConvertTo-SecureString $User.password -AsPlainText -Force)
    }
}
