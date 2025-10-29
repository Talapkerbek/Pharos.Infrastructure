param()

$elasticUrl = $env:ELASTIC_URL
$elasticUser = $env:ELASTIC_USER
$elasticPass = $env:ELASTIC_PASSWORD
$tokenPath = "/tokens/kibana.token"

if (Test-Path $tokenPath) {
    Write-Host "✅ Token already exists at $tokenPath. Skipping creation."
    exit 0
}

Write-Host "⏳ Waiting for Elasticsearch to be ready..."

$maxRetries = 40
$attempt = 0
$ready = $false

while (-not $ready -and $attempt -lt $maxRetries) {
    try {
        $res = Invoke-WebRequest -Uri "$elasticUrl" -UseBasicParsing -TimeoutSec 5
        # 200 OK
        Write-Host "✅ Elasticsearch is up (status $($res.StatusCode))"
        $ready = $true
        break
    }
    catch {
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.Value__
            Write-Host "🔍 Elasticsearch responded with status $statusCode"
            if ($statusCode -in 401,403) {
                Write-Host "✅ Server is up, authentication required (status $statusCode)"
                $ready = $true
                break
            }
        } else {
            Write-Host "❌ Connection failed (no response). Attempt $($attempt + 1)"
        }
    }
        Start-Sleep -Seconds 3
        $attempt++
    }

if (-not $ready) {
    Write-Host "❌ Elasticsearch not ready after $maxRetries attempts. Exiting."
    exit 1
}

Write-Host "🚀 Creating Kibana service token..."

try {
    $response = Invoke-RestMethod `
        -Uri "$elasticUrl/_security/service/elastic/kibana/credential/token/kibana-token?pretty" `
        -Method POST `
        -Authentication Basic `
        -Credential (New-Object System.Management.Automation.PSCredential($elasticUser, (ConvertTo-SecureString $elasticPass -AsPlainText -Force))) `
        -AllowUnencryptedAuthentication

    $tokenValue = $response.token.value
    Out-File -FilePath $tokenPath -Encoding utf8 -InputObject $tokenValue
    Write-Host "✅ Token created and saved to $tokenPath"
} catch {
    Write-Host "❌ Failed to create token:"
    Write-Host $_
    exit 1
}
