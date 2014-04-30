Push-Location $PSScriptRoot
	
# Load assemblies
[System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null

function TestKey([string]$path, [string]$key)
{
    if(!(Test-Path $path)) { return $false }
    if ((Get-ItemProperty $path).$key -eq $null) { return $false }
    return $true
}

function Test-FrameworkNet45()
{
    if(TestKey "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Full" "Install") 
    { 
        $netVersion = (Get-ItemProperty ‘HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full’).Version
        if( $netVersion.StartsWith( "4.5" ))
        {
            Echo "Framework .Net 4.5 is installed.`n"
        }
        else
        {
            Write-Output "You need .Net 4.5 to run this script."
            Exit 1
        }
    }  
    else
    {
        Write-Output "You need .Net 4.5 to run this script."
        Exit 1
    }
}

function Test-PowerShell()
{
    $powershellVersion = $PSVersionTable.PSVersion
    if ( $powershellVersion.Major -lt 3 )
    {
        Write-Output "You need Powershell 3.0 or greater to run this script."
        Exit 1
    }

    Write-Output "Powershell 3.0 or greater is installed.`n"
}

function Request-DirectoryExists ( [string] $path )
{
    if (!(Test-Path -Path $path)) 
    { 
        New-Item $path -Type Directory | Out-Null
    }
}

function RemovePreExistingUnzippedFiles( [string] $buildRootDir )
{
	PrintHeading( "REMOVING PRE-EXISTING UNZIPPED FILES" )
	
    $eigenTargetDir = Join-Path $buildRootDir "\eigen-unzip" 
	
	Write-Output "Removing pre-existing contents in $ToolsDirectory`n"
	Remove-Item $7ZipDirectory -Recurse -Force 2> $null

	Write-Output "Removing pre-existing EIGEN files`n"
	Write-Output "from directory: $eigenTargetDir`n"
	Remove-Item $eigenTargetDir -Recurse -Force 2> $null
	
	PrintFooter( "REMOVED (PRE-EXISTING UNZIPPED FILES)" )
}

function DownloadFile($url, $targetFile)
{
   $uri = New-Object "System.Uri" "$url"
   $request = [System.Net.HttpWebRequest]::Create($uri)
   $request.set_Timeout(60000) #15 second timeout

   Write-Host "Connecting web source: $url `n"
   $response = $request.GetResponse()
   if( !$? -or !$response )
   {
		Write-host "There was an error contacting web-source."
		return "False"
   }
   
   #if the output file already exists.
   if ( Test-Path -Path $targetFile )
   {
		# if the file to download is from the same size as the one in the current directory, we assume is the same one.
		if ( $response.get_ContentLength() -eq (Get-Item $targetFile).Length )
		{
			# We assume it is the same and do not download it.
			Write-host "Target file already exists and has Identical size to web-source. Assuming they are the same."
			Write-host "`t$targetFile`n"
			Write-host "Skipping download.`n`n"

			return "False"
		}
		else 
		{
			$driveLetter = (Get-ChildItem $targetFile).Directory.Root.Name.Replace( ":\", "" )
			$haveEqualSizeInDisk = SizeInDiskIsEqual $driveLetter  ( $response.get_ContentLength() )  ( (Get-Item $targetFile).Length )
			if ( $haveEqualSizeInDisk )
			{
				# We assume it is the same and do not download it.
			    Write-host "Target file already exists and has equal size in disk to web-source. Assuming they are the same."
			    Write-host "`t$targetFile"
				Write-host "Skipping download.`n"

				return "False"
			}
		}
   }

   $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)

   $responseStream = $response.GetResponseStream()
   $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create

   $buffer = New-Object byte[] 512KB
   $count = $responseStream.Read($buffer,0,$buffer.length)
   $downloadedBytes = $count
   while ($count -gt 0)
   {
       $targetStream.Write($buffer, 0, $count)
       $count = $responseStream.Read($buffer,0,$buffer.length)
       $downloadedBytes = $downloadedBytes + $count

       Write-Progress -activity "Downloading file '$($url.split('/') | Select -Last 1)'" -status "Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): " -PercentComplete ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)
   }

   Write-Progress -activity "Finished downloading file '$($url.split('/') | Select -Last 1)'"

   $targetStream.Flush()
   $targetStream.Close()
   $targetStream.Dispose()
   $responseStream.Dispose()

   return "True"
}

function Download ( [string] $sourceUrl, [string] $downloadDir )
{
    Request-DirectoryExists $downloadDir

    # Download the file	
    $uri = New-Object System.Uri($sourceUrl, [System.UriKind]"Absolute")

    $filename = $uri.AbsolutePath.Substring($uri.AbsolutePath.LastIndexOf("/") + 1)
    $file = $downloadDir + "\" + $filename
    $status = DownloadFile $sourceUrl $file

    if( !$status )
    {
		Write-host "Couldn't download Target-file: $file."
		return "False"
    }

    return "True"
}

# Download all prerequisites and stores them in the support directory.
function DownloadAndExtract ( [string] $sourceUrl, [string] $downloadDir, [string] $targetDir )
{
    Request-DirectoryExists $downloadDir

	# Download the file	
    $uri = New-Object System.Uri($sourceUrl, [System.UriKind]"Absolute")

    $filename = $uri.AbsolutePath.Substring($uri.AbsolutePath.LastIndexOf("/") + 1)
    $file = $downloadDir + "\" + $filename

    $status = DownloadFile $sourceUrl $file

    if( !$status )
    {
		Write-host "Couldn't download Target-file: $file."
		return "False"
    }

    Write-host "Unziping package contents to target directory."
    Write-host "`tPackage: `t`t`t$file"
    Write-host "`tTarget directory: `t`t$targetDir`n"

	# Unzip the file to current location
    Request-DirectoryExists $targetDir
	[System.IO.Compression.ZipFile]::ExtractToDirectory($file, $targetDir)

    Write-host "Package unziped!`n"

    return "True"
}

function UnzipFileWith7Zip 
{
    param (
            [string] $ZippedFile = $(throw "ZipFile must be specified."),
            [string] $OutputDir = $(throw "OutputDir must be specified."),
            [string] $7ZipDirectory = $(throw "ZipDirectory must be specified.")
    )
         
    if (!(Test-Path($ZippedFile))) {
            throw "Zip filename does not exist: $ZippedFile"
            return
    }

    # Unzip the file to current location
    $ZipCommand = Join-Path -Path $7ZipDirectory -ChildPath "7za.exe"

    Set-Alias zip $ZipCommand
    zip x -y "-o$OutputDir" $ZippedFile
         
    if (!$?) 
    {
            throw "7-zip returned an error unzipping the file."
    }
}

# Download all prerequisites and stores them in the support directory.
function DownloadAndExtractWith7Zip ( [string] $sourceUrl, [string] $downloadDir, [string] $targetDir, [string] $7ZipDirectory )
{
    Request-DirectoryExists $downloadDir
    Request-DirectoryExists $targetDir

	# Download the file	
    $uri = New-Object System.Uri($sourceUrl, [System.UriKind]"Absolute")

    $filename = $uri.AbsolutePath.Substring($uri.AbsolutePath.LastIndexOf("/") + 1)
    $file = $downloadDir + "\" + $filename

    $status = DownloadFile $sourceUrl $file  

    if( !$status )
    {
		Write-host "Couldn't download Target-file: $file."
		return "False"
    }


    Write-host "Unziping package contents to target directory."
    Write-host "`tPackage: `t`t`t$file"
    Write-host "`tTarget directory: `t`t$targetDir`n"

    # Check if we are dealing with a multi-step decompressing or single-step.
    if ( $file.EndsWith( ".tar.gz" ) )
    {
        # We have a tar.gz, so first we decompress and then extract the files from the tar.
        UnzipFileWith7Zip $file $targetDir $7ZipDirectory
        
        $tarFile = $targetDir + "\" + $filename.Substring( 0, $filename.Length - 3 )
        UnzipFileWith7Zip $tarFile $targetDir $7ZipDirectory

        # We remove the tar file.
        Remove-Item $tarFile
    } 
    elseif ( $file.EndsWith( ".tgz" ) ) 
    {
        # We have a tar.gz, so first we decompress and then extract the files from the tar.
        UnzipFileWith7Zip $file $targetDir $7ZipDirectory
        $tarFile = $targetDir + "\" + $filename.Substring( 0, $filename.Length - 3 ) + "tar"
        
        UnzipFileWith7Zip $tarFile $targetDir $7ZipDirectory
        # We remove the tar file.
        Remove-Item $tarFile
    }
    else
    {
        UnzipFileWith7Zip $file $targetDir $7ZipDirectory
    }

    Write-host "Package unziped!`n"
	
    return "True"
}


# -------------------------------------------------------------------------------------------------------------------

function DownloadAndExtract7Zip ([String] $downloadDirectory, [String] $7ZipDirectory)
{
    Write-Output "Downloading / Extracting 7Zip`n"

    $success = DownloadAndExtract "http://ufpr.dl.sourceforge.net/project/sevenzip/7-Zip/9.20/7za920.zip" $downloadDirectory $7ZipDirectory
    if( !$success )
    {
		Write-host "Couldn't download / extract 7Zip. Every module is required. The process will stop now."
		throw
    }
	
    Write-Output "7Zip download process ended.  Check for status messages.`n`n"
}


function DownloadAndExtractEigen3 ( [string] $buildRootDir, [String] $downloadDirectory, [String] $7ZipDirectory )
{    
    Write-Output "Downloading / Extracting Eigen3`n"

    $eigenTargetDir = Join-Path $downloadDirectory "\eigen-unzip"
    $eigenDestinationDir = Join-Path $buildRootDir "\eigen3"

    # Download and extract the Eigen 3.1.2 version and extract it in a temp directory.
    $success = DownloadAndExtractWith7Zip "https://bitbucket.org/eigen/eigen/get/3.2.1.zip" $downloadDirectory $eigenTargetDir $7ZipDirectory
    if( !$success )
    {
		Write-host "Couldn't download / extract Eigen sources. Every module is required. The process will stop now."
		throw
    }

    Write-Output "Eigen3 download process ended.  Check for status messages.`n`n"
}

function DeployEigen3( [string] $buildRootDir )
{
    $eigenTargetDir = Join-Path $downloadDirectory "\eigen-unzip"
    $eigenDestinationDir = Join-Path $buildRootDir "\eigen3"

    # Copy the output into the proper directory.
    Copy-Item ($eigenSourceDir + "\eigen-eigen-6b38706d90a9\*") -Destination $eigenDestinationDir -Recurse -Force
}

function PrintHeading( [string] $msg )
{
	Write-Output "----------------------------------------------------------------------"
	Write-Output "-- $msg`n"
}

function PrintFooter( [string] $msg )
{
	Write-Output "-- $msg"
	Write-Output "----------------------------------------------------------------------`n`n"
}

# -------------------------------------------------------------------------------------------------------------------
# MAIN
# -------------------------------------------------------------------------------------------------------------------


# Test essential pre-requisites
#------------------------------

Test-FrameworkNet45

Test-PowerShell

# Create a temporary directories
#-------------------------------

# Building output for each library.
$BuildRootDirectory = "./temp-build"
Request-DirectoryExists $BuildRootDirectory

$DownloadRootDirectory = "./temp-build/downloads"
Request-DirectoryExists $DownloadRootDirectory

$7ZipDirectory = Join-Path $BuildRootDirectory "\7zip"
Request-DirectoryExists $7ZipDirectory

# MAIN Functionality
# ------------------

# We move the position to the right build place.
Push-Location $BuildRootDirectory

	PrintHeading( "Starting packages's download/extract process" )

    ### Remove directories where unzipped package contents are going to be placed.
	RemovePreExistingUnzippedFiles $BuildRootDirectory
	
    DownloadAndExtract7Zip $DownloadRootDirectory $7ZipDirectory

    DownloadAndExtractEigen3 $BuildRootDirectory $7ZipDirectory
	
	DeployEigen3 $BuildRootDirectory 	

	PrintFooter( "Finished." )
	
Pop-Location

Pop-Location