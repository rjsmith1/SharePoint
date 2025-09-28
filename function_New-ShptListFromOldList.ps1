function New-ShptListFromOldList {
    param(
        [Object]$SrcConn,
        [Object]$DstConn,
        [string]$ListName,
        [int]$template,
        [string]$ListType,
        [array]$oldListFieldInfo
    )

    Write-Host "Creating $ListType '$ListName'..." -ForegroundColor Magenta
    $dstList = New-PnPList -Title $ListName -Template $template -Connection $DstConn -EnableVersioning
    $dstList = Get-PnPList -Identity $ListName -Connection $DstConn -ErrorAction SilentlyContinue
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
                            $newListFieldSchemaXML = "<Field Type='$($newListField.FieldInternalType)' DisplayName='$($newListField.DisplayName)' Name='$($newListField.InternalName)' ShowField='$((Get-PnPField -List $newListField.LookupListName -Identity $newListField.LookupListColumn -Connection $DstConn).InternalName)' ID='$([guid]::NewGuid().Guid)' ReadOnly='TRUE' FieldRef='$($LookupColumnID)' List='$(($(Get-PnPList -Identity $newListField.LookupListName -Connection $DstConn).Id).Guid)' />"
                        }
                        else {
                            if ($newListField.MultipleValues -eq $true) {
                                $lookupFieldType = "Field Type='LookupMulti' Mult='TRUE'"
                            }
                            else {
                                $lookupFieldType = "Field Type='Lookup'"
                            }
                            $newListFieldSchemaXML = "<$lookupFieldType DisplayName='$($newListField.DisplayName)' Name='$($newListField.InternalName)' ShowField='$($newListField.LookupListColumn)' Required='$($newListField.Required)' ID='$([guid]::NewGuid().Guid)' ReadOnly='TRUE' FieldRef='$($LookupColumnID)' List='$(($(Get-PnPList -Identity $newListField.LookupListName -Connection $DstConn).Id).Guid)' />"
                        }
                    }
                    Default {
                        $newListFieldSchemaXML = "<Field Type='$($newListField.FieldInternalType)' DisplayName='$($newListField.DisplayName)' Name='$($newListField.InternalName)' Description='$($NewListField.Description)' ID='$([guid]::NewGuid().Guid)' ><Default>$($newListField.FieldDefaultValue)</Default></Field>"
                    }
                }
                Add-PnPFieldFromXml -List $dstList.Title -FieldXml $newListFieldSchemaXML -Connection $DstConn 1>$null
                if ($newListField.Indexed -eq $true) {
                    $TargetNewField = Get-PnPField -List $dstList.Title -Identity $newListField.DisplayName -Connection $DstConn
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
    return $dstList
}