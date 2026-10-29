# Build AAB Play Store — beta sslip.io (sans domaine acheté)
param(
    [string]$ApiUrl = "https://164-90-214-206.sslip.io",
    [string]$Domain = "164-90-214-206.sslip.io",
    [switch]$EnableSocialAuth,
    [string]$GoogleWebClientId = "",
    [switch]$SkipSigningSetup
)

& "$PSScriptRoot\publish-play-store.ps1" `
    -ApiUrl $ApiUrl `
    -TermsUrl "https://$Domain/terms" `
    -PrivacyUrl "https://$Domain/privacy" `
    -DeleteAccountUrl "https://$Domain/account-deletion" `
    -EnableSocialAuth:$EnableSocialAuth `
    -GoogleWebClientId $GoogleWebClientId `
    -SkipSigningSetup:$SkipSigningSetup
