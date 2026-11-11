param(
    [ValidatePattern('^[a-z][a-z0-9-]{4,28}[a-z0-9]$')]
    [string]$Project = 'dalttbdd-b3e19',
    [ValidateSet('sandbox', 'production')]
    [string]$Mode = 'sandbox'
)

$ErrorActionPreference = 'Stop'
$partnerCode = Read-Host 'MoMo partnerCode'
if ($partnerCode -notmatch '^[A-Za-z0-9_-]{3,50}$') { throw 'partnerCode khong hop le.' }
$accessKeyInput = Read-Host 'MoMo accessKey (an)' -AsSecureString
$secretKeyInput = Read-Host 'MoMo secretKey (an)' -AsSecureString
$accessPointer = [IntPtr]::Zero
$secretPointer = [IntPtr]::Zero
$configPath = [IO.Path]::GetTempFileName()
try {
    $accessPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($accessKeyInput)
    $secretPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretKeyInput)
    $accessKeyValue = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($accessPointer).Trim()
    $secretKeyValue = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secretPointer).Trim()
    if (!$accessKeyValue -or $secretKeyValue.Length -lt 16) { throw 'accessKey/secretKey khong hop le.' }
    $config = @{ mode = $Mode; partnerCode = $partnerCode; accessKey = $accessKeyValue; secretKey = $secretKeyValue }
    [IO.File]::WriteAllText($configPath, ($config | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding($false)))
    & firebase functions:secrets:set PAWPALS_MOMO_CONFIG --project $Project --data-file $configPath
    if ($LASTEXITCODE -ne 0) { throw 'Khong luu duoc cau hinh MoMo vao Secret Manager.' }
    Write-Host "Da luu cau hinh MoMo ($Mode). Trien khai cac payment functions theo docs/online-payments.md."
} finally {
    if ($accessPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($accessPointer) }
    if ($secretPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secretPointer) }
    if (Test-Path -LiteralPath $configPath) { Remove-Item -LiteralPath $configPath -Force }
    $accessKeyValue = $null
    $secretKeyValue = $null
    $config = $null
    $accessKeyInput.Dispose()
    $secretKeyInput.Dispose()
}
