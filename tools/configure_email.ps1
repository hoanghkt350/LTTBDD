param([string]$Project = 'dalttbdd-b3e19')

$ErrorActionPreference = 'Stop'
$sender = Read-Host 'Gmail dung de gui ma (vi du pawpals@gmail.com)'
if ($sender -notmatch '^[^\s@]+@gmail\.com$') { throw 'Nhap dia chi Gmail hop le.' }
$password = Read-Host 'Mat khau ung dung Gmail (khong phai mat khau dang nhap)' -AsSecureString
$pointer = [IntPtr]::Zero
$configPath = [IO.Path]::GetTempFileName()
try {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    $mailPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer).Replace(' ', '')
    if ($mailPassword.Length -ne 16) { throw 'Mat khau ung dung Gmail gom 16 ky tu.' }
    $random = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $bytes = New-Object byte[] 32
        $random.GetBytes($bytes)
        $otpSecret = [Convert]::ToBase64String($bytes)
    } finally { $random.Dispose() }
    $config = @{ host = 'smtp.gmail.com'; port = 465; user = $sender; password = $mailPassword; otpSecret = $otpSecret }
    [IO.File]::WriteAllText($configPath, ($config | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding($false)))
    & firebase functions:secrets:set PAWPALS_MAIL_CONFIG --project $Project --data-file $configPath
    if ($LASTEXITCODE -ne 0) { throw 'Khong luu duoc cau hinh vao Secret Manager.' }
    Write-Host 'Da luu cau hinh gui email vao Secret Manager. Tiep theo trien khai Cloud Functions theo README.'
} finally {
    if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
    if (Test-Path -LiteralPath $configPath) { Remove-Item -LiteralPath $configPath -Force }
    $mailPassword = $null
    $config = $null
    $password.Dispose()
}
