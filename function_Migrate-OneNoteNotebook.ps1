function Migrate-OneNoteNotebook {
    param( 
        [Parameter(Mandatory = $true)] [string] $SourceSiteUrl, 
        [Parameter(Mandatory = $true)] [string] $SourceNotebookServerRelativeUrl, 
        [Parameter(Mandatory = $true)] [string] $DestSiteUrl, 
        [Parameter(Mandatory = $true)] [string] $DestLibrary, 
        [Parameter(Mandatory = $true)] [string] $DestNotebookName, 
        [Parameter(Mandatory = $true)] [string] $TempPath
    ) 
    # --- Load CSOM assemblies --- 
    Add-Type -Path "C:\Program Files\Common Files\microsoft shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.dll"
    Add-Type -Path "C:\Program Files\Common Files\microsoft shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.Runtime.dll" 
    
    # --- Prepare temp folder --- 
    if (Test-Path $TempPath) { 
        Remove-Item $TempPath -Recurse -Force 
    } 
    New-Item -ItemType Directory -Path $TempPath | Out-Null 
    # --- Connect to source site --- 
    Write-Host "Connecting to source site: $SourceSiteUrl" -ForegroundColor Cyan 
    
    $ctxSrc = New-Object Microsoft.SharePoint.Client.ClientContext($SourceSiteUrl) 
    $ctxSrc.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials 
    
    $webSrc = $ctxSrc.Web 
    $ctxSrc.Load($webSrc) 
    $ctxSrc.ExecuteQuery() 
    # --- Recursive download function --- 
    function Download-FolderCSOM { 
        param(
            $ctx, 
            $folder, 
            $localFolder
        ) 
        # Ensure local folder exists 
        if (!(Test-Path $localFolder)) { 
            New-Item -ItemType Directory -Path $localFolder -Force | Out-Null 
        } # Load files 
        $ctx.Load($folder.Files) 
        $ctx.Load($folder.Folders) 
        $ctx.ExecuteQuery() 
        foreach ($file in $folder.Files) { 
            $localFilePath = Join-Path $localFolder $file.Name 
            Write-Host "Downloading: $($file.ServerRelativeUrl)" 
            # Download binary content 
            $stream = $file.OpenBinaryStream() 
            $ctx.ExecuteQuery() 
            $fs = [System.IO.File]::OpenWrite($localFilePath) 
            $stream.Value.CopyTo($fs) 
            $fs.Close() # Save metadata 
            $meta = [PSCustomObject]@{ 
                ServerRelativeUrl = $file.ServerRelativeUrl 
                Name              = $file.Name 
                Author            = $file.Author.Email 
                Editor            = $file.ModifiedBy.Email 
                Created           = $file.TimeCreated 
                Modified          = $file.TimeLastModified 
            } 
            $meta | Export-Csv -Path (Join-Path $TempPath "metadata.csv") -Append -NoTypeInformation 
        } # Recurse into subfolders 
        foreach ($subFolder in $folder.Folders) { 
            $subLocal = Join-Path $localFolder $subFolder.Name 
            Download-FolderCSOM -ctx $ctx -folder $subFolder -localFolder $subLocal 
        } 
    } 
    # Get source notebook folder 
    $srcFolder = $webSrc.GetFolderByServerRelativeUrl($SourceNotebookServerRelativeUrl) 
    $ctxSrc.Load($srcFolder) 
    $ctxSrc.ExecuteQuery() 
    Write-Host "Starting recursive download of OneNote notebook..." 
    Download-FolderCSOM -ctx $ctxSrc -folder $srcFolder -localFolder (Join-Path $TempPath $DestNotebookName) 
    # --- Connect to destination site (SE) ---
    Write-Host "Connecting to destination site: $DestSiteUrl" -ForegroundColor Cyan 
    Connect-PnPOnline -Url $DestSiteUrl -CurrentCredentials 
    # Ensure destination folder exists 
    Add-PnPFolder -Name $DestNotebookName -Folder $DestLibrary -ErrorAction SilentlyContinue 
    # --- Upload files recursively with metadata --- 
    $metadataMap = Import-Csv (Join-Path $TempPath "metadata.csv") 
    foreach ($localFile in Get-ChildItem -Path (Join-Path $TempPath $DestNotebookName) -Recurse -File) { 
        $relativePath = $localFile.FullName.Substring(($TempPath.Length + 1)) -replace "\\", "/" 
        $targetFolder = ($DestLibrary + "/" + (Split-Path $relativePath -Parent)) -replace "/$", "" 
        Add-PnPFolder -Name (Split-Path $relativePath -Leaf) -Folder $targetFolder -ErrorAction SilentlyContinue | Out-Null 
        $uploadedFile = Add-PnPFile -Path $localFile.FullName -Folder $targetFolder -Force 
        # Apply metadata 
        $match = $metadataMap | Where-Object { $_.Name -eq $localFile.Name } 
        if ($match) { 
            $ctx = Get-PnPContext 
            $file = $ctx.Web.GetFileByServerRelativeUrl($uploadedFile.ServerRelativeUrl) 
            $ctx.Load($file) 
            $ctx.ExecuteQuery() 
            $file.ListItemAllFields["Created"] = [DateTime]$match.Created 
            $file.ListItemAllFields["Modified"] = [DateTime]$match.Modified 
            if ($match.Author) { 
                $file.ListItemAllFields["Author"] = $match.Author 
            }
            if ($match.Editor) { 
                $file.ListItemAllFields["Editor"] = $match.Editor 
            } 
            $file.ListItemAllFields.Update() 
            $ctx.ExecuteQuery() 
        } 
        Write-Host "Uploaded: $relativePath" 
    } 
    Disconnect-PnPOnline Write-Host "✅ OneNote notebook migration completed with metadata preserved!" -ForegroundColor Green 
}