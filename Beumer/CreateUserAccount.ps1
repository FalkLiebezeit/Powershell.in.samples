Add-Type -AssemblyName System.Windows.Forms

function Show-NamePrompt {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Benutzerdaten"
    $form.Width = 360
    $form.Height = 180
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $labelVorname = New-Object System.Windows.Forms.Label
    $labelVorname.Text = "Vorname"
    $labelVorname.Left = 12
    $labelVorname.Top = 16
    $labelVorname.Width = 80

    $textVorname = New-Object System.Windows.Forms.TextBox
    $textVorname.Left = 100
    $textVorname.Top = 12
    $textVorname.Width = 220

    $labelNachname = New-Object System.Windows.Forms.Label
    $labelNachname.Text = "Nachname"
    $labelNachname.Left = 12
    $labelNachname.Top = 52
    $labelNachname.Width = 80

    $textNachname = New-Object System.Windows.Forms.TextBox
    $textNachname.Left = 100
    $textNachname.Top = 48
    $textNachname.Width = 220

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Left = 164
    $okButton.Top = 90
    $okButton.Width = 75
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Abbrechen"
    $cancelButton.Left = 245
    $cancelButton.Top = 90
    $cancelButton.Width = 75
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    $form.AcceptButton = $okButton
    $form.CancelButton = $cancelButton

    $form.Controls.AddRange(@(
        $labelVorname, $textVorname,
        $labelNachname, $textNachname,
        $okButton, $cancelButton
    ))

    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        return $null
    }

    return @{
        Vorname  = $textVorname.Text
        Nachname = $textNachname.Text
    }
}

$nameData = Show-NamePrompt
if (-not $nameData) {
    return
}

$vorname  = $nameData.Vorname
$nachname = $nameData.Nachname
$username = ($vorname.Substring(0, 1) + $nachname)

function Get-RandomPassword {
    param(
        [int] $Length = 10
    )

    $lower   = "abcdefghijklmnopqrstuvwxyz"
    $upper   = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $digits  = "0123456789"
    $special = "!@#$%^&*_-+=?"

    $allChars = ($lower + $upper + $digits + $special).ToCharArray()

    $required = @(
        ($lower.ToCharArray()  | Get-Random -Count 1),
        ($upper.ToCharArray()  | Get-Random -Count 1),
        ($digits.ToCharArray() | Get-Random -Count 1),
        ($special.ToCharArray() | Get-Random -Count 1)
    )

    $remaining = $Length - $required.Count
    $randomRest = @()
    if ($remaining -gt 0) {
        $randomRest = $allChars | Get-Random -Count $remaining
    }

    return ($required + $randomRest | Get-Random -Count $Length) -join ""
}

$password = Get-RandomPassword -Length 10

$templatePath = "C:\Users\Falk\source\repos\Powershell.in.samples\Beumer\User.dotx"
$outputPath   = "C:\Users\Falk\source\repos\Powershell.in.samples\Beumer\Documents\Personendaten_${vorname}.docx"

$word = New-Object -ComObject Word.Application
$word.Visible = $false

# Neues Dokument aus Vorlage erzeugen
$doc = $word.Documents.Add($templatePath)

# Inhaltssteuerelemente füllen
foreach ($cc in $doc.ContentControls) {
    switch ($cc.Tag) {
        "Vorname"  { $cc.Range.Text = $vorname }
        "Nachname" { $cc.Range.Text = $nachname }
        "Username" { $cc.Range.Text = $username }
        "Passwort" { $cc.Range.Text = $password }
    }
}

# Speichern
$doc.SaveAs([ref] $outputPath)

$printResult = [System.Windows.Forms.MessageBox]::Show(
    "Soll das Dokument jetzt gedruckt werden?",
    "Drucken",
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Question
)

if ($printResult -eq [System.Windows.Forms.DialogResult]::Yes) {
    $doc.PrintOut()
}

$doc.Close()
$word.Quit()