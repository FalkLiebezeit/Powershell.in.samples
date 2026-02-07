function New-SecurePassword {
    param(
        [int]$Length = 24
    )

    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+=-{}[]:;,.?'
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)

    -join ($bytes | ForEach-Object { $chars[ $_ % $chars.Length ] })
}

New-SecurePassword -Length 24
