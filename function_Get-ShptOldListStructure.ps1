function Get-ShptOldListStructure {
    param(
        [Object]$SrcConn,
        [string]$ListName
    )
    $oldList = Get-PnPList -Identity $ListName -Connection $SrcConn
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

    Get-PnPProperty -ClientObject $oldList -Property Fields -Connection $SrcConn | Out-Null
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
                    $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name LookupListName -Value (Get-PnPList -Identity $oldListField.LookupList -Connection $SrcConn).Title
                    $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name LookupListColumn -Value $oldListField.LookupField
                    if ($oldListField.IsRelationship -eq $false) {
                        $oldlistFieldObj | Add-Member -MemberType NoteProperty -Name ProjectedField -Value $true
                    }
                }
            }
            $oldListFieldInfo += $oldlistFieldObj
        }
    }
    $result = @{
        oldListFieldInfo = $oldListFieldInfo
        oldListType = $Type
        oldListTemplate = $template
        isLibrary = $isLibrary
        
    }
    return $result
}