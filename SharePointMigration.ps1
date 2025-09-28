### This is for the migration of content from SharePoint16 to SharePoint SE

Import-Module SharePointPnPPowerShell2019 -Force -DisableNameChecking
Import-Module SharePointServer -DisableNameChecking -Force

. d:\scripts\Migration\function_Copy-ShptListItemAttachment.ps1

$FolderName = "Deployables"
$ListName = "Accessories"
$SrcSite = "https://SP16.local/SiteCol1/Site1"
$dstSite = "https://SPSE.local/SiteCol1/Site1"
$incFolder = "D:\Migration\$FolderName\Logs"
$incFile = Join-Path $incFolder "$($ListName.replace(" ", "_"))_LastMigration.txt"
$tmpFolder = "D:\Migration\$FolderName\Content"

if (!(Test-Path $tmpFolder)) {
    New-Item -Path $tmpFolder -ItemType Directory -Force
}
if (!(Test-Path $incFolder)) {
    New-Item -Path $incFolder -ItemType Directory -Force
}

if (!$cred) {
    $cred = Get-Credential
}

$conn1 = Connect-PnPOnline -Url $SrcSite -Credentials $cred -ReturnConnection
$srcCtx1 = Get-PnPContext
$conn2 = Connect-PnPOnline -Url $dstSite -Credentials $cred -ReturnConnection
$dstCtx2 = Get-PnPContext

$scriptStartTime = Get-Date

if (Test-Path $incFile) {
    $lastMigration = Get-Content $incFile | Get-Date
} 
else {
    $lastMigration = get-date "01/01/1900"
}

$oldList = Get-PnPList -Identity $ListName -Connection $conn1
$oldListTitle = $oldList.Title
$template = $oldList.BaseTemplate
switch ($template) {
    '100' { $Type = 'Custom List'; $isLibrary = $false }
    '101' { $Type = 'Document Library'; $isLibrary = $true }
    '102' { $Type = 'Survey'; $isLibrary = $false }
    '103' { $Type = 'Links' }
    '104' { $Type = 'Announcements' }
    '105' { $Type = 'Contacts'; $isLibrary = $false }
    '106' { $Type = 'Calendar'; $isLibrary = $false }
    '107' { $Type = 'Tasks (2010)' }
    '108' { $Type = 'Discussion Board' }
    '109' { $Type = 'Picture Library'; $isLibrary = $true }
    '110' { $Type = 'Data Sources' }
    '115' { $Type = 'Form Library' }
    '117' { $Type = 'No Code Workflows' }
    '118' { $Type = 'Custom Workflow Process' }
    '119' { $Type = 'Wiki Page Library'; $isLibrary = $true }
    '120' { $Type = 'Custom List in Datasheet View' }
    '122' { $Type = 'No Code Public Workflows' }
    '130' { $Type = 'Data Connection Library' }
    '140' { $Type = 'Workflow History'; $isLibrary = $false }
    '150' { $Type = 'Project Tasks' }
    '170' { $Type = 'Promoted Links' }
    '171' { $Type = 'Tasks'; $isLibrary = $false }
    '175' { $Type = 'Maintenance Log Library Template' }
    '432' { $Type = 'Status List' }
    '433' { $Type = 'Report Library' }
    '544' { $Type = 'Persistent Storage List for MySite Published Feed' }
    '600' { $Type = 'External List' }
    '850' { $Type = 'Pages Library'; $isLibrary = $true }
    '851' { $Type = 'Asset Library'; $isLibrary = $true }
    '1100' { $Type = 'Issue Tracking' }
    '10102' { $Type = 'Converted Forms' }
}

Write-Host "`nProcessing $($type): $oldListTitle" -ForegroundColor Magenta

Get-PnPProperty -ClientObject $oldList -Property Fields -Connection $conn1 | Out-Null
$oldListFields = $oldList.Fields
$oldListFieldInfo = @()
foreach ($oldListField in $oldListFields) {
    Clear-Variable oldListFieldSchemaXML -ErrorAction SilentlyContinue
    [Xml]$oldListFieldSchemaXML = $oldListField.SchemaXml
    if (($oldListField.InternalName -eq "Title" -or $oldListField.InternalName -eq "Author" -or $oldListField.InternalName -eq "Editor") -or ($oldListField.Hidden -eq $false -and $oldListField.CanBeDeleted -eq $true -and $oldListField.TypeAsString -ne "WorkflowStatus")) {
        $oldlistFieldObj = New-Object PSObject
        $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name Hidden -Value $oldListField.Hidden
        $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name CanBeDeleted -Value $oldListField.CanBeDeleted
        $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name DisplayName -Value $oldListField.Title.Replace("'", '"')
        $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name InternalName -Value $oldListField.InternalName.trim().replace(" ", "_x0020_")
        $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name FieldType -Value $oldListField.TypeDisplayName
        $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name FieldInternalType -Value $oldListField.TypeAsString
        $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name FieldDescription -Value $oldListField.Description.Replace("'", '"')
        $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name FieldDefaultValue -Value $oldListField.DefaultValue
        $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name Required -Value $oldListField.Required
        $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name RequireUnique -Value $oldListField.EnforceUniqueValues
        $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name Indexed -Value $oldListField.Indexed
        switch -Wildcard ($oldListField.TypeAsString) {
            "Text" { 
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name FieldMaxLength -Value $oldListField.MaxLength 
            }
            "Note" { 
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name AppendChanges -Value $oldListField.AppendOnly
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name RichText -Value $oldListField.RichText
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name NumberOfLines -Value $oldListField.NumberOfLines
                if ($oldListFieldSchemaXML.Field.RichTextMode) {
                    $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name RichTextMode -Value $oldListFieldSchemaXML.Field.RichTextMode
                }
            }
            { "Choice" -or "MultiChoice" } {
                if ($oldListField.EditFormat) {
                    $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name ChoiceType -Value $oldListField.EditFormat
                }
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name Choices -Value $oldListField.Choices
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name FillInChoice -Value $oldListField.FillInChoice
            }
            { "Number" -or "Currency" } {
                if ($oldListField.CurrencyLocaleId) {
                    $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name CurrencyLocaleId -Value $oldListField.CurrencyLocaleId
                }
                if ($oldListField.MinimumValue -ne [double]::MinValue) {
                    $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name MinValue -Value $oldListField.MinimumValue
                }
                if ($oldListField.MaximumValue -ne [double]::MaxValue) {
                    $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name MaxValue -Value $oldListField.MaximumValue
                }
                if ($oldListFieldSchemaXML.Field.Decimals) {
                    $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name Decimals -Value $oldListFieldSchemaXML.Field.Decimals
                }
                if ($oldListFieldSchemaXML.Field.Percentage) {
                    $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name ShowAsPercent -Value $oldListFieldSchemaXML.Field.Percentage
                }
                else {
                    $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name ShowAsPercent -Value "FALSE"
                }
            }
            "DateTime" {
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name DateDisplayFormat -Value $oldListField.DisplayFormat
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name DateFriendlyDisplay -Value $oldListField.FriendlyDisplayFormat
                if ($oldListFieldSchemaXML.Field.RichTextMode) {
                    $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name DefaultFormula -Value $oldListFieldSchemaXML.Field.DefaultFormula
                }
            }
            "Boolean" {
                #Nothing Additional required for Boolean Fields
            }
            "User" {
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name AllowMultipleUsers -Value $oldListField.AllowMultipleUsers
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name UserShowField -Value $oldListField.LookupField
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name UserChooseFrom -Value $oldListField.SelectionGroup
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name SelectionFrom -Value $oldListField.SelectionMode
            }
            "Url" {
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name URLFormat -Value $oldListField.DisplayFormat
            }
            "Calculated" {
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name CalcOutputType -Value $oldListField.OutputType
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name Formula -Value $oldListFieldSchemaXML.Field.Formula
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name FormulaDisplay -Value $oldListFieldSchemaXML.Field.FormulaDisplayNames
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name DateFormat -Value $oldListField.DateFormat
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name FieldRefs -Value $oldListFieldSchemaXML.Field.FieldRefs.FieldRef.Name
                if ($oldListFieldSchemaXML.Field.LCID) {
                    $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name CurrencyLocaleId -Value $oldListFieldSchemaXML.Field.LCID
                }
                if ($oldListFieldSchemaXML.Field.Percentage) {
                    $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name ShowAsPercent -Value $oldListFieldSchemaXML.Field.Percentage
                }
                else {
                    $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name ShowAsPercent -Value "FALSE"
                }
            }
            "Looku*" {
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name MultipleValues -Value $oldListField.AllowMultipleValues
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name LookupListName -Value (Get-PnPList -Identity $oldListField.LookupList -Connection $conn1).Title
                $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name LookupListColumn -Value $oldListField.LookupField
                if ($oldListField.IsRelationship -eq $false) {
                    $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name ProjectedField -Value $true
                }
            }
        }
        $oldListFieldInfo += $oldlistFieldObj
    }
}

$endOldListTime = Get-Date
Write-Host "It took $([math]::Round(($endOldListTime - $scriptStartTime).TotalSeconds, 2)) seconds to get the old list field definitions" -ForegroundColor Yellow

$dstList = Get-PnPList -Identity $oldListTitle -Connection $conn2 -ErrorAction SilentlyContinue
if (!$dstList) {
    $StartNewListTime = Get-Date
    Write-Host "Creating $Type '$ListName'..." -ForegroundColor Magenta
    $dstList = New-PnPList -Title $ListName -Template $template -Connection $conn2 -EnableVersioning
    $dstList = Get-PnPList -Identity $dstList.Title -Connection $conn2 -ErrorAction SilentlyContinue
    $newTitle = "Title"
    foreach ($newListField in $oldListFieldInfo) {
        Clear-Variable newListFieldSchemaXML -ErrorAction SilentlyContinue
        if ($newListField.CanBeDeleted -eq $false) {
            if ($newListField.InternalName -eq "Title" -and $newListField.DisplayName -ne "Title") {
                $newTitle = $($newListField.DisplayName)
                Write-Warning "Updating 'Title' field name to $($newListField.DisplayName)"
                Set-PnPField -List $dstList.Title -Identity "Title" -Values @{Title = "$newTitle" } 1>$null
            }
            else {
                switch -Wildcard ($newListField.FieldInternalType) {
                    "Text" { 
                        $newListFieldSchemaXML = "<Field Type='$($newListField.FieldInternalType)' DisplayName='$($newListField.DisplayName)' Name='$($newListField.InternalName)' Description='$($NewListField.Description)' ID='$([guid]::NewGuid().Guid)' Required='$($newListField.Required)' Indexed='$($newListField.Indexed)' MaxLength='$($newListField.FieldMaxLength)'><Default>$($newListField.FieldDefaultValue)</Default></Field>"
                    }
                    "Note" { 
                        if ($newListField.RichText -eq $true) {
                            $newListFieldSchemaXML = "<Field Type='$($newListField.FieldInternalType)' DisplayName='$($newListField.DisplayName)' Name='$($newListField.InternalName)' Description='$($NewListField.Description)' ID='$([guid]::NewGuid().Guid)' Required='$($newListField.Required)' Indexed='$($newListField.Indexed)' NumLines='$($newListField.NumberOfLines)' RichText='$($newListField.RichText)' RichTextMode='$($newListField.RichTextMode)'><Default>$($newListField.FieldDefaultValue)</Default></Field>"
                        } 
                        else {
                            $newListFieldSchemaXML = "<Field Type='$($newListField.FieldInternalType)' DisplayName='$($newListField.DisplayName)' Name='$($newListField.InternalName)' Description='$($NewListField.Description)' ID='$([guid]::NewGuid().Guid)' Required='$($newListField.Required)' Indexed='$($newListField.Indexed)' NumLines='$($newListField.NumberOfLines)' RichText='$($newListField.RichText)'><Default>$($newListField.FieldDefaultValue)</Default></Field>"
                        }
                    }
                    "*Choice" {
                        Clear-Variable FieldChoices -ErrorAction SilentlyContinue
                        Clear-Variable FieldChoice -ErrorAction SilentlyContinue
                        foreach ($fieldchoice in $newListField.Choices) {
                            $fieldchoice = "<CHOICE>$($fieldchoice)</CHOICE>"
                            $fieldchoices = $fieldchoices + $fieldchoice
                        }
                        $newListFieldSchemaXML = "<Field Type='$($newListField.FieldInternalType)' DisplayName='$($newListField.DisplayName)' Name='$($newListField.InternalName)' Description='$($NewListField.Description)' ID='$([guid]::NewGuid().Guid)' Required='$($newListField.Required)' Indexed='$($newListField.Indexed)' Format='$($newListField.ChoiceType)' FillInChoice='$($newListField.FillInChoice)'><Default>$($newListField.FieldDefaultValue)</Default><CHOICES>$fieldchoices</CHOICES></Field>"
                    }
                    { "Number" -or "Currency" } {
                        Clear-Variable numXml -ErrorAction SilentlyContinue
                        if ($newListField.ShowAsPercent) {
                            $numXml = " Percentage='$($newListField.ShowAsPercent)'"
                        }
                        if ($newListField.Decimals) {
                            $numXml = " Decimals='$($newListField.Decimals)'$numXml"
                        }
                        if ($newListField.MaxValue) {
                            $numXml = " Max='$($newListField.MaxValue)'$numXml"
                        }
                        if ($newListField.MinValue) {
                            $numXml = " Min='$($newListField.MinValue)'$numXml"
                        }
                        if ($newListField.CurrencyLocaleId) {
                            $numXml = " Decimals='$($newListField.CurrencyLocaleId)'$numXml"
                        }
                        $newListFieldSchemaXML = "<Field Type='$($newListField.FieldInternalType)' DisplayName='$($newListField.DisplayName)' Name='$($newListField.InternalName)' Description='$($NewListField.Description)' ID='$([guid]::NewGuid().Guid)' Required='$($newListField.Required)' Indexed='$($newListField.Indexed)'$numXml><Default>$($newListField.FieldDefaultValue)</Default></Field>"
                    }
                    "DateTime" {
                        if ($newListField.DefaultFormula) {
                            $newListFieldSchemaXML = "<Field Type='$($newListField.FieldInternalType)' DisplayName='$($newListField.DisplayName)' Name='$($newListField.InternalName)' Description='$($NewListField.Description)' ID='$([guid]::NewGuid().Guid)' Required='$($newListField.Required)' Indexed='$($newListField.Indexed)' Format='$($newListField.DateDisplayFormat)' FriendlyDisplayFormat='$($newListField.DateFriendlyDisplay)'><DefaultFormula>$($newListField.DefaultFormula)</DefaultFormula></Field>"
                        }
                        else {
                            $newListFieldSchemaXML = "<Field Type='$($newListField.FieldInternalType)' DisplayName='$($newListField.DisplayName)' Name='$($newListField.InternalName)' Description='$($NewListField.Description)' ID='$([guid]::NewGuid().Guid)' Required='$($newListField.Required)' Indexed='$($newListField.Indexed)' Format='$($newListField.DateDisplayFormat)' FriendlyDisplayFormat='$($newListField.DateFriendlyDisplay)'><Default>$($newListField.FieldDefaultValue)</Default></Field>"
                        }
                    }
                    "Boolean" {
                        $newListFieldSchemaXML = "<Field Type='$($newListField.FieldInternalType)' DisplayName='$($newListField.DisplayName)' Name='$($newListField.InternalName)' Description='$($NewListField.Description)' ID='$([guid]::NewGuid().Guid)'><Default>$($newListField.FieldDefaultValue)</Default></Field>"
                    }
                    "User*" {
                        if ($newListField.FieldInternalType -eq "UserMulti") { $Multi = " Mult='TRUE'" }
                        $newListFieldSchemaXML = "<Field Type='$($newListField.FieldInternalType)' DisplayName='$($newListField.DisplayName)' Name='$($newListField.InternalName)' Description='$($NewListField.Description)' ID='$([guid]::NewGuid().Guid)' Required='$($newListField.Required)' ShowField='$($newListField.UserShowField)' UserSelectionMode='$($newListField.SelectionFrom)' UserSelectionScope='$($newListField.UserChooseFrom)'$Multi><Default>$($newListField.FieldDefaultValue)</Default></Field>"
                    }
                    "Url" {
                        $newListFieldSchemaXML = "<Field Type='$($newListField.FieldInternalType)' DisplayName='$($newListField.DisplayName)' Name='$($newListField.InternalName)' Description='$($NewListField.Description)' ID='$([guid]::NewGuid().Guid)' Required='$($newListField.Required)' Indexed='$($newListField.Indexed)' Format='$($newListField.UrlFormat)' ><Default>$($newListField.FieldDefaultValue)</Default></Field>"
                    }
                    "Calculated" {
                        Clear-Variable FormulaField -ErrorAction SilentlyContinue
                        Clear-Variable FormulaFields -ErrorAction SilentlyContinue
                        Clear-Variable CalcStr -ErrorAction SilentlyContinue
                        if ($newListField.Decimals) {
                            $CalcStr = " Decimals='$($newListField.Decimals)'"
                        }
                        if ($newListField.CurrencyLocaleId) {
                            $CalcStr = $CalcStr + " LCID='$($newListField.CurrencyLocaleId)'"
                        }
                        if ($newListField.ShowAsPercent) {
                            $CalcStr = $CalcStr + " Percentage='$($newListField.ShowAsPercent)'"
                        }
                        if ($newListField.DateFormat) {
                            $CalcStr = $CalcStr + " Format='$($newListField.DateFormat)'"
                        }
                        foreach ($FormulaField in $newListField.FieldRefs) {
                            $FormulaField = "<FieldRef Name='$($FormulaField.Replace("_x0020_", " "))' />"
                            $FormulaFields = $FormulaFields + $FormulaField
                        }
                        $newListFieldSchemaXML = "<Field Type='$($newListField.FieldInternalType)' DisplayName='$($newListField.DisplayName)' Name='$($newListField.InternalName)' Description='$($NewListField.Description)' ID='$([guid]::NewGuid().Guid)' ReadOnly='TRUE' Indexed='$($newListField.Indexed)' ResultType='$($newListField.CalcOutputType)'$CalcStr><Formula>$($newListField.FormulaDisplay)</Formula><FieldRefs>$FormulaFields</FieldRefs></Field>"
                    }
                    "Lookup*" {
                        Clear-Variable LookupColumnID -ErrorAction SilentlyContinue
                        if ($newListField.InternalName -match "x003a" -and $newListField.ProjectedField -eq $true) {
                            $LookupColumnID = (Get-PnPField -List $dstList.Title -Identity $newListField.InternalName.Split("_")[0]).Id
                            $newListFieldSchemaXML = "<Field Type='$($newListField.FieldInternalType)' DisplayName='$($newListField.DisplayName)' Name='$($newListField.InternalName)' ShowField='$((Get-PnPField -List $newListField.LookupListName -Identity $newListField.LookupListColumn -Connection $conn2).InternalName)' ID='$([guid]::NewGuid().Guid)' ReadOnly='TRUE' FieldRef='$($LookupColumnID)' List='$(($(Get-PnPList -Identity $newListField.LookupListName -Connection $conn2).Id).Guid)' />"
                        }
                        else {
                            if ($newListField.MultipleValues -eq $true) {
                                $lookupFieldType = "Field Type='LookupMulti' Mult='TRUE'"
                            }
                            else {
                                $lookupFieldType = "Field Type='Lookup'"
                            }
                            $newListFieldSchemaXML = "<$lookupFieldType DisplayName='$($newListField.DisplayName)' Name='$($newListField.InternalName)' ShowField='$($newListField.LookupListColumn)' Required='$($newListField.Required)' ID='$([guid]::NewGuid().Guid)' ReadOnly='TRUE' FieldRef='$($LookupColumnID)' List='$(($(Get-PnPList -Identity $newListField.LookupListName -Connection $conn2).Id).Guid)' />"
                        }
                    }
                    Default {
                        $newListFieldSchemaXML = "<Field Type='$($newListField.FieldInternalType)' DisplayName='$($newListField.DisplayName)' Name='$($newListField.InternalName)' Description='$($NewListField.Description)' ID='$([guid]::NewGuid().Guid)' ><Default>$($newListField.FieldDefaultValue)</Default></Field>"
                    }
                }
                Add-PnPFieldFromXml -List $dstList.Title -FieldXml $newListFieldSchemaXML -Connection $conn2 1>$null
                if ($newListField.Indexed -eq $true) {
                    $TargetNewField = Get-PnPField -List $dstList.Title -Identity $newListField.DisplayName -Connection $conn2
                    if ($TargetNewField.Indexed -eq $false) {
                        $TargetNewField.Indexed = $true
                        $TargetNewField.Update()
                    }
                    $TargetNewField.EnforceUniqueValues = $newListField.RequireUnique
                    $TargetNewField
                }
            }
        }
    }
    $endNewListTime = Get-Date
    Write-Host "It took $([math]::Round(($endNewListTime - $StartNewListTime).TotalSeconds, 2)) seconds to create the list and configure the list field definitions" -ForegroundColor Yellow
}
else {
    # Don't do anything; the list already exists... Happy Days
}

$startViewCreateTime = Get-Date
$oldViews = Get-PnPView -List $ListName -Connection $conn1
foreach ($oldView in $oldViews) {
    $oldViewFields = @()
    foreach ($OldViewField in $oldView.ViewFields) {
        $oldViewFields += $OldViewField
    }
    Clear-Variable oldViewValues -ErrorAction SilentlyContinue
    $oldViewValues = @{}
    if ($oldView.Aggregations) {
        $oldViewValues.Add("AggregationsStatus", $oldView.AggregationsStatus)
        $oldViewValues.Add("Aggregations", $oldView.Aggregations)
    }
    if ($oldView.TabularView) {
        $oldViewValues.Add("TabularView", $oldView.TabularView)
    }
    $oldViewValues.Add("ViewQuery", $oldView.ViewQuery)
    $oldViewValues.Add("RowLimit", $oldView.RowLimit)
    if ($oldView.ServerRelativeUrl -match "/AllItems.aspx" -and $oldView.Title -ne "All Items" -and !(Get-PnPView -List $ListName -Identity $oldView.Title -Connection $conn2 -ErrorAction SilentlyContinue)) {
        $oldViewValues.Add("Title", $oldView.Title)
        Set-PnPView -List $ListName -Identity "All Items" -Fields $oldViewFields -Values $oldViewValues -Connection $conn2 1>$null
    }
    elseif (!(Get-PnPView -List $ListName -Identity $oldView.Title -Connection $conn2 -ErrorAction SilentlyContinue)) {
        if ($oldview.Personal) {
            $newListView = Add-PnPView -List $ListName -Title $oldView.Title -Fields $oldViewFields -ViewType $oldView.ViewType -Personal -Connection $conn2
        }
        elseif ($oldView.DefaultView) {
            $newListView = Add-PnPView -List $ListName -Title $oldView.Title -Fields $oldViewFields -ViewType $oldView.ViewType -SetAsDefault -Connection $conn2
        }
        else {
            $newListView = Add-PnPView -List $ListName -Title $oldView.Title -Fields $oldViewFields -ViewType $oldView.ViewType -Connection $conn2
        }
        Set-PnPView -List $ListName -Identity $newListView.Title -Values $oldViewValues -Connection $conn2 1>$null
    }
}
$endViewCreateTime = Get-Date
Write-Host "It took $([math]::Round(($endViewCreateTime - $startViewCreateTime).TotalSeconds, 2)) seconds to create $($oldViews.Count) list views" -ForegroundColor Yellow

$StartCreateItemsTime = Get-Date
# Reconnect to source to fetch items
$NewWeb = Get-SPWeb $dstSite
$newList = Get-PnPList -Identity $oldlistTitle -Connection $conn2
$oldListItems = Get-PnPListItem -List $ListName -PageSize 5000 - Connection $conn1 | Where-Object { $_.FieldValues.Modified -gt $lastMigration } | Sort-Object ID
Get-PnPProperty -ClientObject newList -Property Fields | Out-Null
$NewListItemFields = $newList.Fields
Write-Host "$($oldListItems.Count) items to migrate..."
#$i = 0
#$ii = 2
foreach ($oldListItem in $oldListItems) {
    #$i++; $item.FieldValues. Title; Sitem. FileSystemObject Type; if(Si -eq Sii) {'STOP"; break}}
    $fieldValues = $oldListItem.Field.Values
    if ($isLibrary) {
        Get-PnPProperty -ClientObject $oldListItem.Folder -Property Files -Connection $conn1 | Out-Null
        Get-PnPProperty -ClientObject $dstList -Property Fields -Connection $conn2 | Out-Null
        if ($oldListItem.FileSystemObjectType -eq "Folder") {
            Clear-Variable FullPath -ErrorAction SilentlyContinue
            $FullPath = $oldListItem.FieldValues. FileRef.replace($oldlist.RootFolder.ServerRelativeUrl, $dstList.RootFolder.ServerRelativeUrl).replace($dstList.ParentWebUrl, "")
            Resolve-PnPFolder $FullPath -Connection $conn2 1>$null
        }
        elseif ($oldListItem.FileSystemObjectType -eq "File") {
            Clear-Variable downloaded -ErrorAction SilentlyContinue
            Get-PnPProperty -ClientObject $oldListItem -Property FieldValues -ErrorAction SilentlyContinue | Out-Null
            $fileUrl = $oldListItem.FieldValues.FileRef
            $fileName = $oldListItem.FieldValues.FileLeafRef
            $UploadPath = $oldListItem.FieldValues.FileDirRef.replace($oldList.RootFolder.ServerRelativeUrl, $dstList.RootFolder.ServerRelativeUrl).replace($dstList.ParentWebUrl, "")
            $NewtempFolder = Join-Path $tmpFolder $UploadPath.replace("/", "(")
            if (-not (Test-Path $NewtempFolder)) { 
                New-Item -Path $NewtempFolder -ItemType Directory -Force 
            }
            $localFile = Join-Path $NewtempFolder $fileName
            $srcCtx1.ExecuteQuery() | Out-Null
            $stream = [Microsoft.SharePoint.Client.File]::OpenBinaryDirect($srcCtx1, $fileUrl)
            $FileStream = New-Object System.IO.FileStream($localFile, [System.IO.FileMode]::Create)
            $stream.Stream.CopyTo($FileStream)
            $filestream.Close()
            $stream.stream.close()
            $downloaded = Test-Path $localFile
            if ($downloaded) {
                $Upload = Add-PnPFile -Path $localFile -NewFileName $fileName.replace("&", "and") -Folder $UploadPath -Connection $conn2
                if ($Upload) {
                    Remove-Item $localFile -Force
                }
                else {
                    Write-Warning "Failed to upload file: $fileName"
                }
            }
            else {
                Write-Warning "Failed to download file: $fileName"
            }
        }
        Clear-Variable author -ErrorAction SilentlyContinue
        $author = if ($fieldValues["Author"].LookupValue -eq "EADIE, Rob J AUS GOV" -or $fieldValues["Author"].LookupValue -eq "rjeadie-a") {
            "Domain\svc-shpt-prodadm"
        }
        else {
            "$($fieldValues["Author"].Email)"
        }
        $author = if (!($NewWeb.EnsureUser($author) | Out-Null )) {
            New-PnPUser -LoginName $fieldValues["Author"].Email.Split("@")[0] -Connection $conn2 1>$null
        }
        elseif ($NewWeb.EnsureUser($author) | Out-Null) {
            $NewWeb.EnsureUser($author) 2>$null
        }
        else {
            $NewWeb.EnsureUser("domain\svc-shot-prodadm") 2>$null
        }
        Clear-Variable editor -ErrorAction SilentlyContinue
        $editor = if ($fieldValues["editor"].LookupValue -eq "EADIE, Rob J AUS GOV" -or $fieldValues["editor"].LookupValue -eq "rjeadie-a") {
            "Domain\svc-shpt-prodadm"
        }
        else {
            "$($fieldValues["editor"].Email)"
        }
        $editor = if (!($NewWeb.EnsureUser($editor) | Out-Null)) {
            New-PnPUser -LoginName $fieldValues["editor"].Email.Split("@")[0] -Connection $conn2 1>$null
        }
        elseif ($NewWeb.EnsureUser($editor) | Out-Null) {
            $NewWeb.EnsureUser($editor) 2>$null
        }
        else {
            $NewWeb.EnsureUser("domain\svc-shot-prodadm") 2>$null
        }
        $NewItem = Get-PnPListItem -List $ListName -Connection $conn2 | Where-Object { $_.FieldValues.FileLeafRef -eq $fieldValues.FileLeafRef.Replace("&", "and") }
        Set-PnPListItem -List $ListName -Identity $NewItem.id `
            -Values @{
            "Author"   = $author.UserLogin
            "Editor"   = $editor.UserLogin
            "Created"  = $fieldValues["Created"]
            "Modified" = $fieldValues["Modified"]
        } -Connection $conn2 1>$null
    }
    else {
        #Regular List Item
        $NewFieldsDict = @{}
        foreach ($NewListItemField in $NewListItemFields) {
            Clear-Variable NewListItemFieldValue -ErrorAction SilentlyContinue
            if ($NewListItemField.InternalName -eq "Title" -or ($NewListItemField.Hidden -eq $false -and $NewListItemField.CanBeDeleted -eq $true)) {
                if ($NewListItemField.FieldTypeKind -eq "WorkflowStatus" -or $NewListItemField.FieldTypeKind -eq "Calculated" -or $NewListItemField.FieldTypeKind -eq "Computed") { 
                    Continue #Do nothing, WorkflowStatus field is not necessary as it won't link to the Workflow from SP16 and Calculated/Computed fields are generated automatically
                }
                if ($NewListItemField.FieldTypeKind -match "Lookup") {
                    if ($NewListItemField.Title -like "*:*" -or $NewListItemField.InternalName -like "*_x003a_*") {
                        Continue
                    }
                    else {
                        Clear-Variable ListToQuery -ErrorAction SilentlyContinue
                        Clear-Variable LookupQuery -ErrorAction SilentlyContinue
                        $ListToQuery = (Get-PnPList -Identity ($NewListItemField.LookupList) -Connection $conn1).Title
                        $NewListItemFieldValue = (Get-PnPListItem -List $ListToQuery -Connection $conn2 | where { $_.FieldValues[$NewListItemField.LookupField] -eq $fieldValues[$NewListItemField.StaticName].LookupValue }).Id
                    }
                } 
                elseif ($NewListItemField.FieldTypeKind -match "User") {
                    if ($fieldValues[$NewListItemField.StaticName] -eq $null) {
                        Continue
                    }
                    else {
                        # I need a check here to see how a UserMulti value stores users; is it in an array/hasht able or plain text. This will dictate if I need to put a foreach loop in to appropriately ensureUser/NewUser
                        Clear-Variable user -ErrorAction SilentlyContinue
                        Clear-Variable email -ErrorAction SilentlyContinue
                        $user = "domain\" + $fieldValues[$NewListItemField.StaticName].Email.Split("@")[0]
                        if ($user -like "*.*") {
                            $email = Get-PnPUser | Where-Object Email -eq $fieldValues[$NewListItemField.StaticName].Email
                            if ($email) {
                                $NewWeb = get-SPWeb $dstSite
                                $NewListItemFieldValue = ($NewWeb.EnsureUser($user)).Userlogin
                                if (!$NewListItemFieldValue) {
                                    $NewListItemFieldValue = New-PnPUser -LoginName $user -Connection $conn2 1>$null
                                }
                            }
                        }
                    }
                }
                else {
                    $NewListItemFieldValue = $fieldValues[$NewListItemField.StaticName]
                }
                $NewFieldsDict[$NewListItemField.StaticName] = $NewListItemFieldValue
            }
        }
        Clear-Variable AlreadyExists -ErrorAction SilentlyContinue
        Clear-Variable ExistingItem -ErrorAction SilentlyContinue
        $AlreadyExists = Get-PnPListItem -List $ListName -PageSize 5000 -Connection $conn2 | Where-Object { $_.FieldValues.Title -eq $fieldValues.Title -and (Get-Date $fieldValues.Created.ToLocalTime() -Format "yyyy-MM-ddTHH:mm:ss.ffffffZ") }
        if ($AlreadyExists.Count -gt 1) {
            foreach ($ExistingItem in $AlreadyExists) {
                if ((Get-Date $fieldValues.Created.ToLocalTime() -Format "yyyy-MM-ddTHH:mm:ss.ffffffZ") -eq (Get-Date $ExistingItem.Created.ToLocalTime() -Format "yyyy-MM-ddTHH:mm:ss.ffffffZ") -or (Get-Date -Format "yyyy-MM-dd") -eq (Get-Date $ExistingItem.Created.ToLocalTime() -Format "yyyy-MM-dd")) {
                    $updateID = $ExistingItem.Id
                    $NewOrUpdate = "Update"
                }
                elseif ((get-date $fieldValues.Created.ToLocalTime() -Format "yyyy-MM-ddTHH:mm:ss.ffffffZ") -ne (get-date $ExistingItem.Created.ToLocalTime() -Format "yyyy-MM-ddTHH:mm:ss.ffffffZ")) {
                    # Do Nothing...
                }
                else {
                    Write-Warning "What Do? $($fieldValues.Title):$($fieldValues.Id)"
                }
            }
        }
        elseif ($AlreadyExists.Count -eq 1) {
            # Need to update existing Item
            $updateID = $ExistingItem.Id
            $NewOrUpdate = "Update"
        }
        else {
            # Need to create new item
            $NewOrUpdate = "New"
        }
        Clear-Variable author -ErrorAction SilentlyContinue
        $author = if ($fieldValues["Author"].LookupValue -eq "EADIE, Rob J AUS GOV" -or $fieldValues["Author"].LookupValue -eq "rjeadie-a") {
            "Domain\svc-shpt-prodadm"
        }
        else {
            "$($fieldValues["Author"].Email)"
        }
        $author = if (!($NewWeb.EnsureUser($author) | Out-Null)) {
            New-PnPUser -LoginName $fieldValues["Author"].Email.Split("@")[0] -Connection $conn2 1>$null
        }
        elseif ($NewWeb.EnsureUser($author) | Out-Null) {
            $NewWeb.EnsureUser($author) 2>$null
        }
        else {
            $NewWeb.EnsureUser("domain\svc-shot-prodadm") 2>$null
        }
        Clear-Variable editor -ErrorAction SilentlyContinue
        $editor = if ($fieldValues["editor"].LookupValue -eq "EADIE, Rob J AUS GOV" -or $fieldValues["editor"].LookupValue -eq "rjeadie-a") {
            "Domain\svc-shpt-prodadm"
        }
        else {
            "$($fieldValues["editor"].Email)"
        }
        $editor = if (!($NewWeb.EnsureUser($editor) | Out-Null)) {
            New-PnPUser -LoginName $fieldValues["editor"].Email.Split("@")[0] -Connection $conn2 1>$null
        }
        elseif ($NewWeb.EnsureUser($editor) | Out-Null) {
            $NewWeb.EnsureUser($editor) | Out-Null
        }
        else {
            $NewWeb.EnsureUser("domain\svc-shot-prodadm") 2>$null
        }
        Clear-Variable NewListItemId -ErrorAction SilentlyContinue
        Switch ($NewOrUpdate) {
            "New" { 
                Clear-Variable NewListItem -ErrorAction SilentlyContinue
                $NewListItem = Add-PnPListItem -List $ListName -Values $NewFieldsDict -Connection $conn2
                if ($NewListItem) {
                    $NewListItemId = $NewListItem.Id
                    $dstItem = Get-PnPListItem -list $ListName -Id $NewListItemId -Connection $conn2
                    Get-PnPProperty $oldListItem -Property AttachmentFiles -Connection $conn2 | Out-Null
                    if($oldListItem.AttachmentFiles.Count -ge 1) {
                        Copy-ShptListItemAttachment -SourceContext $srcCtx1 -SourceItem $oldListItem -DestinationContext $dstCtx2 -DestinationItem $dstItem
                    }
                    Set-PnPListItem -List $ListName -Identity $NewListItem.Id `
                        -Values @{
                        "Author"   = $author.UserLogin
                        "Editor"   = $editor.UserLogin
                        "Created"  = $fieldValues["Created"]
                        "Modified" = $fieldValues["Modified"]
                    } -Connection $conn2 1>$null
                    
                }
                else {
                    Write-Warning "$($NewFieldsDict.Title) was not created in $ListName"
                }
            }
            "Update" {
                Clear-Variable SetItem -ErrorAction SilentlyContinue
                $SetListItem = Set-PnPListItem -Identity $updateID -Values $NewFieldsDict -ContentType $conn2
                if ($SetListItem) {
                    Write-Warning "$($SetListItem.FieldValues.Title):$($SetListItem.Id) has been updated"
                    Set-PnPListItem -List $ListName -Identity $SetListItem.Id `
                        -Values @{
                        "Editor"   = $editor.UserLogin
                        "Modified" = $fieldValues["Modified"]
                    } -Connection $conn2 1>$null
                    $NewListItemId = $SetListItem.Id
                }
            }
        }
    }
}
$endCreateItemsTime = Get-Date
Write-Host "It took $([math]::Round(($endCreateItemsTime - $StartCreateItemsTime).TotalSeconds, 2)) seconds to create $($oldListItems.Count) list items" -ForegroundColor Yellow

(Get-Date).ToString("s") | Out-File $incFile -Force

Write-Host "`nMigration complete. Next run will only copy items modified after $(Get-Date -Format 's')" -ForegroundColor Green

$scriptEndTime = Get-Date
Write-Host "It took $([math]::Round(($scriptEndTime - $scriptStartTime).TotalMinutes, 2)) minutes to re-create $ListName of type $type in $dstSite" -ForegroundColor Yellow