param(
    [String[]]$ToIds,
    [String[]]$ToMails,
    [String[]]$CcIds,
    [String]$Subject,
    [String]$Message,
    [String]$Organization,
    [String]$ProjectId,
    [int[]]$WorkItems
)

$body = $Message.replace("\r",$([char]10)).replace("\n",$([char]13))

$JSONbody = @{
    "fields"=@(
        "System.Id",
        "System.Title",
        "System.AssignedTo",
        "System.WorkItemType",
        "System.State"
    )
    "message"= @{
        "to" = @{
            "tfIds" = $ToIds
            "emailAddresses" = $ToMails
        }
        "cc"= @{
            "tfids" = $CcIds
        }
        "replyTo"= @{
            "tfids" =@()
        }
        "subject"= $Subject
        "body"= $body
    }
    "projectId"= $ProjectId
    "ids"= $WorkItems
}

.\scripts\invoke-rest-api -Uri "https://dev.azure.com/$Organization/$ProjectId/_apis/wit/sendmail?api-version=7.1-preview.1" -Method POST -Body ($JSONbody | ConvertTo-Json -depth 8)