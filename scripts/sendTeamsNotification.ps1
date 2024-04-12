param (
    [String]$ActionTitle,
    [String]$ActionUrl,
    [String]$Title,
    [String]$Message,
    [String]$ChannelGUID,
    [String]$UserName,
    [String]$UserId
)

function Post-Api {
    param (
        $Uri,
        $Headers,
        $Body
    )
    $token = ConvertTo-SecureString -String $env:REST_TOKEN -AsPlainText -Force
    $creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "minestardevops",$token
    $Uri = $Uri.replace(' ', '%20')
    Write-Host "Uri: '$Uri"
    try {
        Invoke-RestMethod -Method POST -Authentication Basic -Credential $creds -Uri $Uri -Headers $Headers -Body ($Body | ConvertTo-Json -Depth 8)
        Write-Host "##vso[task.setvariable variable=invokeRestResult;]$true"
    } catch {
        Write-Error $_
        Write-Host "##vso[task.setvariable variable=invokeRestResult;]$false"
    }
}

$headers = @{
    "Content-Type"="application/json"
}

$body = @{
    "type"= "message"
    "attachments" = @(
    @{
        "contentType"= "application/vnd.microsoft.card.adaptive"
        "content"= @{
            "type"= "AdaptiveCard"
            "actions" = @(
                @{
                    "type"= "Action.OpenUrl"
                    "title"= "$ActionTitle"
                    "url"= "$ActionUrl"
                }
            )
            "body" = @(
                @{
                    "type"= "TextBlock"
                    "text"= "$Title"
                    "size"= "Medium"
                    "weight"= "Bolder"
                    "wrap"=$true
                },
                @{
                    "type"= "TextBlock"
                    "text"= "$Message"
                    "wrap"=$true
                }
            )
            "`$schema"= "http://adaptivecards.io/schemas/adaptive-card.json"
            "version"= "1.2"
            "msteams"= @{
                "width"= "Full"
                "entities"=@()
            }
        }
    })
}

if ($UserId -ne '') {
    $body."attachments"."content"."msteams"."entities" = @(
        @{
            "type"= "mention"
            "text"= "<at>$UserName</at>"
            "mentioned"= @{
                "name"= "$UserName"
                "id"= "$UserId"
            }
        }
    )
}

Post-Api -Uri "https://<organisation>.webhook.office.com/webhookb2/$ChannelGUID" -Headers $headers -Body $body
