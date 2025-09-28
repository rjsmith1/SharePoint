function Copy-ShptListItemAttachment {
    param (
        [Microsoft.SharePoint.Client.ClientContext]$SourceContext,
        [Microsoft.SharePoint.Client.ListItem]$SourceItem,
        [Microsoft.SharePoint.Client.ClientContext]$DestinationContext,
        [Microsoft.SharePoint.Client.ListItem]$DestinationItem
    )
    $oldListItemAttachments = $SourceItem.AttachmentFiles
    $SourceContext.Load($oldListItemAttachments)
    $SourceContext.ExecuteQuery()

    foreach ($att in $oldListItemAttachments) {
        Write-Host "Migrating attachment: '$($att.FileName)' -for list item: $($DestinationItem.Id) - '$($DestinationItem.FieldValues.Title)'" -f Yellow

        $fileInfo = [Microsoft.SharePoint.Client.File]::OpenBinaryDirect($SourceContext, $att.ServerRelativeUrl)
        $ms = New-Object IO.MemoryStream
        $fileInfo.Stream.CopyTo($ms)
        $bytes = $ms.ToArray()
        $ms.Dispose()

        $attachInfo = New-Object Microsoft.SharePoint.Client.AttachmentCreationInformation
        $attachInfo.FileName = $att.FileName
        $attachInfo.ContentStream = New-Object IM.MemoryStream(,$bytes)

        $DestinationItem.AttachmentFiles.Add($attachInfo) 1>$null

        try {
            $DestinationContext.ExecuteQuery() 1>$null
        }
        catch {
            Write-Warning "Failed to upload attachment '$($att.FileName)' for list item: $($DestinationItem.Id) - '$($DestinationItem.FieldValues.Title)'`nError: $_"
        }
    }
}