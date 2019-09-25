#=================================================================================#
# PowerShell script sample for coolOrange powerJobs                               #
# Creates a PDF file and uploads it to to Sharepoint   #
#                                                                                 #
# Copyright (c) coolOrange s.r.l. - All rights reserved.                          #
#                                                                                 #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER       #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES     #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.      #
#=================================================================================#

# Install-Module -Name SharePointPnPPowerShellOnline -RequiredVersion 3.2.1810.0

$hidePDF = $false
$workingDirectory = "C:\Temp\$($file._Name)"
$localPDFfileLocation = "$workingDirectory\$($file._Name).pdf"
$vaultPDFfileLocation = $file._EntityPath +"/"+ (Split-Path -Leaf $localPDFfileLocation)
$fastOpen = $file._Extension -eq "idw" -or $file._Extension -eq "dwg" -and $file._ReleasedRevision

$Username = ""
$Password = ConvertTo-SecureString -String "" -AsPlainText -Force
[System.Management.Automation.PSCredential]$PSCredentials  = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ($Username, $Password)
# Please enter the link of your Sharepoint site
$Site = ""

try { 
    Connect-PnPOnline -Url $Site -Credential $PSCredentials 
    if (-not (Get-PnPContext)) { 
        Write-Host "Error connecting to SharePoint Online, unable to establish context" -foregroundcolor black -backgroundcolor Red 
        return 
    } 
} catch { 
    Write-Host "Error connecting to SharePoint Online: $_.Exception.Message" -foregroundcolor black -backgroundcolor Red
    return 
}
Write-Host "Starting job 'Create PDF and upload it to Sharepoint' for file '$($file._Name)' ..."

if( @("idw","dwg") -notcontains $file._Extension ) {
    Write-Host "Files with extension: '$($file._Extension)' are not supported"
    return
}

$downloadedFiles = Save-VaultFile -File $file._FullPath -DownloadDirectory $workingDirectory -ExcludeChildren:$fastOpen -ExcludeLibraryContents:$fastOpen
$file = $downloadedFiles | Select-Object -First 1
$openResult = Open-Document -LocalFile $file.LocalPath -Options @{ FastOpen = $fastOpen } 

if($openResult) {
    if($openResult.Application.Name -like 'Inventor*') {
        $configFile = "$($env:POWERJOBS_MODULESDIR)Export\PDF_2D.ini"
    } else {
        $configFile = "$($env:POWERJOBS_MODULESDIR)Export\PDF.dwg" 
    }                  
    $exportResult = Export-Document -Format 'PDF' -To $localPDFfileLocation -Options $configFile 

    if($exportResult) {
        $PDFfile = Add-VaultFile -From $localPDFfileLocation -To $vaultPDFfileLocation -FileClassification DesignVisualization -Hidden $hidePDF
        $file = Update-VaultFile -File $file._FullPath -AddAttachments @($PDFfile._FullPath)
    }
    
    # Please enter in which folder you want to safe the files
    Add-PnPFile -Path $localPDFfileLocation -Folder ""
    $closeResult = Close-Document
}

Clean-Up -folder $workingDirectory

if(-not $openResult) {
    throw("Failed to open document $($file.LocalPath)! Reason: $($openResult.Error.Message)")
}
if(-not $exportResult) {
    throw("Failed to export document $($file.LocalPath) to $localPDFfileLocation! Reason: $($exportResult.Error.Message)")
}
if(-not $closeResult) {
    throw("Failed to close document $($file.LocalPath)! Reason: $($closeResult.Error.Message))")
}

Write-Host "Completed job 'Create PDF and upload it to Sharepoint'"