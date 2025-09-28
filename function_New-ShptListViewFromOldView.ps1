function New-ShptListViewFromOldView {
    param(
        [object]$SrcConn,
        [object]$DstConn,
        [string]$ListName
    )
    $oldViews = Get-PnPView -List $ListName -Connection $SrcConn
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
        if ($oldView.ServerRelativeUrl -match "/AllItems.aspx" -and $oldView.Title -ne "All Items" -and !(Get-PnPView -List $ListName -Identity $oldView.Title -Connection $DstConn -ErrorAction SilentlyContinue)) {
            $oldViewValues.Add("Title", $oldView.Title)
            Set-PnPView -List $ListName -Identity "All Items" -Fields $oldViewFields -Values $oldViewValues -Connection $DstConn 1>$null
        }
        elseif (!(Get-PnPView -List $ListName -Identity $oldView.Title -Connection $DstConn -ErrorAction SilentlyContinue)) {
            if ($oldview.Personal) {
                $newListView = Add-PnPView -List $ListName -Title $oldView.Title -Fields $oldViewFields -ViewType $oldView.ViewType -Personal -Connection $DstConn
            }
            elseif ($oldView.DefaultView) {
                $newListView = Add-PnPView -List $ListName -Title $oldView.Title -Fields $oldViewFields -ViewType $oldView.ViewType -SetAsDefault -Connection $DstConn
            }
            else {
                $newListView = Add-PnPView -List $ListName -Title $oldView.Title -Fields $oldViewFields -ViewType $oldView.ViewType -Connection $DstConn
            }
            Set-PnPView -List $ListName -Identity $newListView.Title -Values $oldViewValues -Connection $DstConn 1>$null
        }
    }
}