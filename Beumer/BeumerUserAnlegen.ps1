#requires -Version 5.1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:TemplatePath = Join-Path $PSScriptRoot "BeumerUserAnlegen.docx"

function Show-UserInputForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "BeumerUserAnlegen"
    $form.Size = New-Object System.Drawing.Size(420, 200)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $labelFirst = New-Object System.Windows.Forms.Label
    $labelFirst.Text = "Vorname:"
    $labelFirst.Location = New-Object System.Drawing.Point(20, 20)
    $labelFirst.AutoSize = $true

    $textFirst = New-Object System.Windows.Forms.TextBox
    $textFirst.Location = New-Object System.Drawing.Point(120, 18)
    $textFirst.Width = 250

    $labelLast = New-Object System.Windows.Forms.Label
    $labelLast.Text = "Nachname:"
    $labelLast.Location = New-Object System.Drawing.Point(20, 60)
    $labelLast.AutoSize = $true

    $textLast = New-Object System.Windows.Forms.TextBox
    $textLast.Location = New-Object System.Drawing.Point(120, 58)
    $textLast.Width = 250

    $buttonOk = New-Object System.Windows.Forms.Button
    $buttonOk.Text = "OK"
    $buttonOk.Location = New-Object System.Drawing.Point(210, 110)
    $buttonOk.DialogResult = [System.Windows.Forms.DialogResult]::OK

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = "Abbrechen"
    $buttonCancel.Location = New-Object System.Drawing.Point(295, 110)
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    $form.AcceptButton = $buttonOk
    $form.CancelButton = $buttonCancel

    $form.Controls.AddRange(@(
        $labelFirst, $textFirst,
        $labelLast, $textLast,
        $buttonOk, $buttonCancel
    ))

    while ($true) {
        $result = $form.ShowDialog()
        if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
            return $null
        }

        $firstName = $textFirst.Text.Trim()
        $lastName = $textLast.Text.Trim()

        if ([string]::IsNullOrWhiteSpace($firstName) -or [string]::IsNullOrWhiteSpace($lastName)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Bitte Vorname und Nachname eingeben.",
                "Eingabe erforderlich",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            continue
        }

        return [PSCustomObject]@{
            FirstName = $firstName
            LastName  = $lastName
        }
    }
}

function Set-WordContent {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Document,
        [Parameter(Mandatory = $true)]
        [string]$FirstName,
        [Parameter(Mandatory = $true)]
        [string]$LastName
    )

    $replaced = $false
    $contentControlTitles = @()
    $contentControlTags = @()
    $bookmarkNames = @()

    # Try Content Controls by Title/Tag
    foreach ($cc in @($Document.ContentControls)) {
        $title = $cc.Title
        $tag = $cc.Tag
        if (-not [string]::IsNullOrWhiteSpace($title)) {
            $contentControlTitles += $title
        }
        if (-not [string]::IsNullOrWhiteSpace($tag)) {
            $contentControlTags += $tag
        }
        if ($title -eq "FirstName" -or $tag -eq "FirstName") {
            $cc.Range.Text = $FirstName
            $replaced = $true
        }
        if ($title -eq "LastName" -or $tag -eq "LastName") {
            $cc.Range.Text = $LastName
            $replaced = $true
        }
    }

    # Try Bookmarks
    foreach ($bm in @($Document.Bookmarks)) {
        if (-not [string]::IsNullOrWhiteSpace($bm.Name)) {
            $bookmarkNames += $bm.Name
        }
    }
    if ($Document.Bookmarks.Exists("FirstName")) {
        $Document.Bookmarks.Item("FirstName").Range.Text = $FirstName
        $replaced = $true
    }
    if ($Document.Bookmarks.Exists("LastName")) {
        $Document.Bookmarks.Item("LastName").Range.Text = $LastName
        $replaced = $true
    }

    # Fallback: replace placeholders
    if (-not $replaced) {
        $map = @{
            "<<FirstName>>"  = $FirstName
            "<<LastName>>"   = $LastName
            "<<Vorname>>"    = $FirstName
            "<<Nachname>>"   = $LastName
            "<FirstName>"    = $FirstName
            "<LastName>"     = $LastName
            "<Vorname>"      = $FirstName
            "<Nachname>"     = $LastName
            "{FirstName}"    = $FirstName
            "{LastName}"     = $LastName
            "{Vorname}"      = $FirstName
            "{Nachname}"     = $LastName
            "[FirstName]"    = $FirstName
            "[LastName]"     = $LastName
            "[Vorname]"      = $FirstName
            "[Nachname]"     = $LastName
            "{{FirstName}}"  = $FirstName
            "{{LastName}}"   = $LastName
            "{{Vorname}}"    = $FirstName
            "{{Nachname}}"   = $LastName
        }
        foreach ($key in $map.Keys) {
            $find = $Document.Content.Find
            $find.Text = $key
            $find.Replacement.Text = $map[$key]
            $find.MatchCase = $false
            $find.MatchWholeWord = $false
            $find.MatchWildcards = $false
            $find.Forward = $true
            $find.Wrap = 1 # wdFindContinue
            $found = $find.Execute($null, $null, $null, $null, $null, $null, $null, $null, $null, $find.Replacement.Text, 2)
            if ($found) {
                $replaced = $true
            }
        }
    }

    if (-not $replaced) {
        $titleList = ($contentControlTitles | Sort-Object -Unique) -join ", "
        $tagList = ($contentControlTags | Sort-Object -Unique) -join ", "
        $bmList = ($bookmarkNames | Sort-Object -Unique) -join ", "
        $placeholderList = ($map.Keys | Sort-Object -Unique) -join ", "

        $message = "Keine passenden Felder gefunden. `n"
        $message += "Content Controls (Title): $titleList`n"
        $message += "Content Controls (Tag): $tagList`n"
        $message += "Bookmarks: $bmList`n"
        $message += "Gesuchte Platzhalter: $placeholderList"

        [System.Windows.Forms.MessageBox]::Show(
            $message,
            "Hinweis",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
}

function New-BeumerUserDocument {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FirstName,
        [Parameter(Mandatory = $true)]
        [string]$LastName
    )

    if (-not (Test-Path $script:TemplatePath)) {
        throw "Vorlage nicht gefunden: $script:TemplatePath"
    }

    $word = $null
    $doc = $null
    try {
        $word = New-Object -ComObject Word.Application
        $word.Visible = $true

        $doc = $word.Documents.Add($script:TemplatePath)
        Set-WordContent -Document $doc -FirstName $FirstName -LastName $LastName

        $rawName = "{0}_{1}_BeumerUserAnlegen.docx" -f $FirstName, $LastName
        $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
        $safeName = ($rawName.ToCharArray() | ForEach-Object {
            if ($invalidChars -contains $_) { '_' } else { $_ }
        }) -join ''
        $outputPath = Join-Path $PSScriptRoot $safeName
        $doc.SaveAs($outputPath, 16) | Out-Null # 16 = wdFormatXMLDocument
    }
    finally {
        if ($doc -ne $null) {
            $doc.Close($false) | Out-Null
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($doc) | Out-Null
        }
        if ($word -ne $null) {
            $word.Quit() | Out-Null
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
        }
    }
}

$user = Show-UserInputForm
if ($null -ne $user) {
    New-BeumerUserDocument -FirstName $user.FirstName -LastName $user.LastName
}
