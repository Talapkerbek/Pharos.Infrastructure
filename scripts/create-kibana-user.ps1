# Ждём пока Elasticsearch запустится
$elasticUrl = "http://elasticsearch:9200"
$elasticUser = "elastic"
$elasticPass = "elasticpassword"

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

$userData = @{
    password  = "kibana_password"
    roles     = @("kibana_system")
    full_name = "Kibana System User"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$elasticUrl/_security/user/kibana_user" `
                                  -Method POST `
                                  -Credential (New-Object System.Management.Automation.PSCredential($elasticUser, (ConvertTo-SecureString $elasticPass -AsPlainText -Force))) `
                                  -Body $userData `
                                  -ContentType "application/json" `
                                  -ErrorAction Stop
    Write-Host "✅ User 'kibana_user' created successfully."
} catch {
    Write-Host "❌ Failed to create user 'kibana_user':"
    Write-Host $_
    exit 1
}