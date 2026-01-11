param(
    [string]$CsvFile = "",
    [string]$OUPath  = "",
    [string]$DomainName = ""
)

# Ensure ActiveDirectory module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "ActiveDirectory module not found. Install RSAT/AD module or run on a domain-joined host."
    exit 1
}

Import-Module ActiveDirectory -ErrorAction Stop

# Read CSV (explicit encoding if needed)
try {
    $userList = Import-Csv -Path $CsvFile -Encoding UTF8
} catch {
    Write-Error "Failed to read CSV '$CsvFile': $_"
    exit 1
}

foreach ($User in $userList) {
    # Basic validation & normalization
    $username  = ($User.username  -as [string]).Trim()
    $firstname = ($User.firstname -as [string]).Trim()
    $lastname  = ($User.lastname  -as [string]).Trim()
    $password  = ($User.password  -as [string])

    if ([string]::IsNullOrWhiteSpace($username) -or [string]::IsNullOrWhiteSpace($password)) {
        Write-Warning "Skipping entry with missing username or password: $($User | Out-String)"
        continue
    }

    # sAMAccountName length check (common NetBIOS limit)
    if ($username.Length -gt 20) {
        Write-Warning "Username '$username' is longer than 20 chars. Truncating to 20 characters."
        $username = $username.Substring(0,20)
    }

    # Avoid spaces in sAMAccountName (recommended)
    if ($username.Contains(' ')) {
        Write-Warning "Username '$username' contains spaces. Replacing spaces with underscore."
        $username = $username -replace '\s','_'
    }

    # Check user existence
    $exists = Get-ADUser -Filter "sAMAccountName -eq '$username'" -ErrorAction SilentlyContinue
    if ($exists) {
        Write-Warning "User '$username' already exists. Skipping."
        continue
    }

    # Convert password to SecureString
    try {
        $securePass = ConvertTo-SecureString -String $password -AsPlainText -Force
    } catch {
        Write-Error "Failed to convert password for '$username': $_"
        continue
    }

    $userParam = @{
        SamAccountName        = $username
        UserPrincipalName     = "$username@$DomainName"
        Name                  = "$firstname $lastname".Trim()
        GivenName             = $firstname
        Surname               = $lastname
        Enabled               = $True
        ChangePasswordAtLogon = $True
        PasswordNeverExpires  = $False
        DisplayName           = "$firstname $lastname".Trim()
        Path                  = $OUPath
        AccountPassword       = $securePass
        ErrorAction           = 'Stop'
    }

    try {
        New-ADUser @userParam
    } catch {
        Write-Error "Failed to create user '$username': $_"
    }
}
