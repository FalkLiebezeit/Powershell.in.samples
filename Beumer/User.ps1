$vorname  = "Falk"
$nachname = "Mustermann"

$templatePath = "C:\Users\Falk\source\repos\Powershell.in.samples\Beumer\User.dotx"
$outputPath   = "C:\Users\Falk\source\repos\Powershell.in.samples\Beumer\Personendaten_Falk.docx"

$word = New-Object -ComObject Word.Application
$word.Visible = $false

# Neues Dokument aus Vorlage erzeugen
$doc = $word.Documents.Add($templatePath)

# Inhaltssteuerelemente füllen
foreach ($cc in $doc.ContentControls) {
    switch ($cc.Tag) {
        "Vorname"  { $cc.Range.Text = $vorname }
        "Nachname" { $cc.Range.Text = $nachname }
    }
}

# Speichern
$doc.SaveAs([ref] $outputPath)
$doc.Close()
$word.Quit()