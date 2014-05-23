# InstallGuiExtension -sourceFile "C:\RC\code\gui-ext-ps1\CopyUri-master.zip" -guiExtensionName "Copy URI"

write-output "/***
*     _____ _    _ _____   ______      _                 _               _____           _        _ _           
*    / ____| |  | |_   _| |  ____|    | |               (_)             |_   _|         | |      | | |          
*   | |  __| |  | | | |   | |__  __  _| |_ ___ _ __  ___ _  ___  _ __     | |  _ __  ___| |_ __ _| | | ___ _ __ 
*   | | |_ | |  | | | |   |  __| \ \/ / __/ _ \ '_ \/ __| |/ _ \| '_ \    | | | '_ \/ __| __/ _` | | |/ _ \ '__|
*   | |__| | |__| |_| |_  | |____ >  <| ||  __/ | | \__ \ | (_) | | | |  _| |_| | | \__ \ || (_| | | |  __/ |   
*    \_____|\____/|_____| |______/_/\_\\__\___|_| |_|___/_|\___/|_| |_| |_____|_| |_|___/\__\__,_|_|_|\___|_|   
*                                                                                                               
*                                                                                                               
"
write-output "1********************************************************************"
write-output "*           Tridion GUI Extensions Installer 1.2                   *"
write-output "*           Created by Robert Curlette, Yabolka                    *"
write-output "*                                                                  *"
write-output "*  Info:  Installs a Tridion GUI Extension by doing the following: *"
write-output "*  - Copy Editor folder to Webroot/Editors                         *"
write-output "*  - Create VDir in Editors section in Tridion IIS                 *"
write-output "*  - Update System.config                                          *"
write-output "*                                                                  *"
write-output "*  Optional, if existing:                                          *"
write-output "*  - Copy dll files to WebRoot bin                                 *"
write-output "*  - Copy Model Folder and files                                   *"
write-output "*                                                                  *"
write-output "*  Assumes the following folders exist:                            *"
write-output "*       /Editor/											         *"
write-output "*       /Editor/Configuration/editor.config                        *"
write-output "*                                                                  *"
write-output "*       Optional:                                                  *"
write-output "*       /Model/                                                    *"
write-output "*       /Model/Configuration/model.config                          *"
write-output "*       /dlls/                                                     *"
write-output "*                                                                  *"
write-output "********************************************************************"

#ToDo:
# - If fail, undo changes to system.config or IIS
	# - Test bool success flag for all operations touching the filesystem or IIS
	# - Only if all are success, show success msg, otherwise, rollback
# - Check if files exist before copying
	# - Check if extension exists in IIS before adding
	# - Check if web.config contains extension before copying

    

function InstallGuiExtension
{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True)]
   [string]$sourceFile,

   [Parameter(Mandatory=$True)]
   [string]$guiExtensionName
)
    trap{"An error occurred while running the script.  The extension is not installed correctly.  Please confirm your folder structure meets the above requirements."}

    # import various stuff we need
    [Reflection.Assembly]::LoadWithpartialName("System.Xml.Linq") | Out-Null
    
    # import webadministration module (if > iis7.5) or snapin (if iis7 )
    $iisVersion = Get-ItemProperty "HKLM:\software\microsoft\InetStp";
    if ($iisVersion.MajorVersion -eq 7)
    {
        if ($iisVersion.MinorVersion -ge 5)
        {
            Import-Module WebAdministration;
        }           
        else
        {
            if (-not (Get-PSSnapIn | Where {$_.Name -eq "WebAdministration";})) {
                Add-PSSnapIn WebAdministration;
            }
        }
    }
   
    if(GuiExtensionExistsInIIS -extensionName $guiExtensionName)
    {
        write-error("Extension exists in IIS and we're exiting.")
        exit
    }

    if(!(Test-Path $sourcefile))
    {
	    write-error("Cannot find file with name '" + $sourcefile + "'. Please check filename and try again.")
	    exit
    }

    if(!($sourcefile.EndsWith(".zip")))
    {
        write-error("Error: Source file is not a .zip, '" + $sourcefile + "'. Please check filename and try again.")
	    exit
    }

    Write-Verbose("GUI Extension " + $sourcefile + " installation beginning...");

    ExtractFiles($sourceFile)

    # Get GUI Extension Name
    #if($sourcefile.Contains("."))
    #{
	#    $guiExtensionName = $sourcefile.Split(".")[0]
    #}
    #else
    #{
	#    $guiExtensionName = $sourcefile
    #}

    #Editor Folder
    $containerFolderPath = $sourceFile.Substring(0, $sourceFile.LastIndexOf('\'))
    Set-Location($containerFolderPath)    
    $editorPath = ".\Editor"
    # Exit if no Editor folder found
    if(!(Test-Path Editor -pathType container))
    {
	    # Github format
	    if(Test-Path $guiExtensionName\Editor -pathType container)
	    {
		    $editorPath = $guiExtensionName + '\Editor'
	    }
	    else
	    {
		    write-output ("Error:  No 'Editor' folder found.  Please make sure your .zip file contans an 'Editor' folder.")
		    exit
	    }
    }
    write-output("  Editor folder found at " +  $editorPath)

    #Model folder exists?
    if(Test-Path Model -pathType container)
    {
	    [bool]$hasModel = 1
    }


    #Tridion CME Install Location
    $tridionInstallLocationUserDefined = Read-Host "Where is Tridion installed? (Default is C:\Program Files (x86)\Tridion)"
    [string]$tridionInstallLocation = "C:\Program Files (x86)\Tridion\"

    if(!([string]::IsNullOrWhitespace($tridionInstallLocationUserDefined)))  # if($tridionInstallLocationUserDefined -ne "")
    {
	    $tridionInstallLocation = $tridionInstallLocationUserDefined
    }

    [string]$editorInstallLocation = $tridionInstallLocation + "web\WebUI\Editors\" + $guiExtensionName + "\Editor"
    [string]$modelInstallLocation = $tridionInstallLocation + "web\WebUI\Models\" + $guiExtensionName + "\Model"



    # Set config file name and path
    $editorConfigFile = Read-Host "Name of editor configuration file?  Default is 'Configuration\editor.config"
    if(([string]::IsNullOrWhitespace($editorConfigFile)))
    {
	    $editorConfigFile= "Configuration\editor.config"
    }

    if($hasModel)
    {
	    $modelConfigFile = Read-Host "Name of model configuration file (if any)?  Default is 'Configuration\editor.config"
	    if(([string]::IsNullOrWhitespace($modelConfigFile)))
	    {
		    $modelConfigFile= "Configuration\model.config"
	    }
    }

    write-output ("-> Begin Installing GUI Extension Editor to " + $editorInstallLocation + ". Editor config file: " + $editorConfigFile)
  
     #************* Copy Editor and Model files *******************  
    Copy-Item -Path $editorPath $editorInstallLocation -recurse
    # ! Not sure this test-path works - especially with the dynamic config file now
    if((Test-Path $editorInstallLocation\Configuration\Editor -pathType container))
    {
	    write-output ("  Success:  GUI Extension Editor Files copied to " + $editorInstallLocation)
    }

    if(!(Test-Path $editorInstallLocation\Configuration\editor.config))
    {
	    write-output("  Error:  No editor config found at " + $editorInstallLocation + "\Configuration\editor.config + , exiting.")
	    exit
    }
    # ! end not sure part 


    if($hasModel)
    {
	    write-output ("Begin Copying Model files to " + $modelInstallLocation)
	    Copy-Item -Path ".\Model" $modelInstallLocation -recurse
	    write-output ("  Success:  GUI Extension Model Files copied to " + $modelInstallLocation)
    }


    #************* Copy DLLs ******************* 
    if(Test-Path dlls -pathType container)
    {
	    $webRootBin = $tridionInstallLocation + "\web\WebUI\WebRoot\bin"        
	    write-output ("Begin Copying DLLs to " + $webRoot)
	    Copy-Item -Path "dlls\*" $webRootBin -recurse
	    write-output ("  Success:  Copied DLLs to " + $webRoot)
    }


    #************* Update Config *******************
    # Update System.config
    write-output ("Begin updating system.config")
    $configFilename = $tridionInstallLocation + '\web\WebUI\WebRoot\Configuration\System.config'
    $conf = [xml](gc $configFilename)

    #  "http://www.sdltridion.com/2009/GUI/Configuration" <-- Correct for 2011 and 2013??
    # specify some namespace so we don't have empty xmlns in the children

    # Editor
    write-output ("Begin adding Editor to system.config")
    $editors = [System.Xml.XmlElement]$conf.Configuration.editors
    $myElement = $conf.CreateElement("editor", "http://www.sdltridion.com/2009/GUI/Configuration")
    $sourcefileAttr = $myElement.SetAttribute("name", $guiExtensionName)

    $installPathElement = $conf.CreateElement("installpath", "http://www.sdltridion.com/2009/GUI/Configuration")
    $installPathElement.InnerText = $editorInstallLocation
    $myElement.AppendChild($installPathElement)

    $configurationElement = $conf.CreateElement("configuration", "http://www.sdltridion.com/2009/GUI/Configuration")
    $configurationElement.InnerText = $editorConfigFile
    $myElement.AppendChild($configurationElement)

    $vdirElement = $conf.CreateElement("vdir", "http://www.sdltridion.com/2009/GUI/Configuration")
    $vdirElement.InnerText = $guiExtensionName
    $myElement.AppendChild($vdirElement)
    # $myElement.InnerXml = "<installpath>" + $editorInstallLocation + "</installpath><configuration>" + $editorConfigFile + "</configuration><vdir>" + $guiExtensionName + "</vdir>"

    $editors.AppendChild($myElement)

    write-output ("  Success:  Editor added to system.config")

    #Model

    if($hasModel)
    {
	    write-output ("Begin adding Model to system.config")
	    $models = [System.Xml.XmlElement]$conf.Configuration.models
	    $myModelElement = $conf.CreateElement("model")
	    $sourcefileAttr = $myModelElement.SetAttribute("name", $guiExtensionName)
	    $installPathElement = $conf.CreateElement("installpath", "http://www.sdltridion.com/2009/GUI/Configuration")
	    $installPathElement.InnerText = $modelInstallLocation
	    $myModelElement.AppendChild($installPathElement)

	    $configurationElement = $conf.CreateElement("configuration", "http://www.sdltridion.com/2009/GUI/Configuration")
	    $configurationElement.InnerText = $modelConfigFile
	    $myModelElement.AppendChild($configurationElement)

	    $vdirElement = $conf.CreateElement("vdir", "http://www.sdltridion.com/2009/GUI/Configuration")
	    $vdirElement.InnerText = $guiExtensionName
	    $myModelElement.AppendChild($vdirElement)
	    $models.AppendChild($myModelElement)
	    write-output ("  Success:  Model added to system.config")
    }

    $conf.Save($configFilename)
    write-output ("  Success:  Updated and saved system.config")


    #************* Update IIS *******************  
    # Create VDIR in Tridion/WebUI/Editors and Models  2011 / 2013 need input 
    $tridionVersion = Read-Host "Which version of Tridion do you use? (2011 or 2013).  Default is 2013).  This is used to find the correct Tridion CME Website in IIS"
    if(($tridionVersion -ne "2011") -and($tridionVersion -ne "2013"))
    {
	    $tridionVersion = "2013"
    }

    write-output ("Begin updating IIS, adding Editor")
    $tridionIISPath = Get-IISTridionSitePath($tridionVersion);
    $vdirPathEditor = $tridionIISPath + '\WebUI\Editors\' + $guiExtensionName;
    New-Item $vdirPathEditor -type VirtualDirectory -physicalPath $editorInstallLocation
    write-output ("  Success:  Updating IIS and added new Virtual Dir at " + $vdirPathEditor)

    # Model
    if($hasModel)
    {
	    write-output ("Begin updating IIS, adding Model")
	    $vdirPathModel = $tridionIISPath + '\WebUI\Models\' + $guiExtensionName 
	    New-Item $vdirPathModel -type VirtualDirectory -physicalPath $modelInstallLocation
	    write-output ("  Success:  Updating IIS and added new Virtual Dir at " + $vdirPathModel)
    }
       
    write-output ("============================================")
    write-output ("Finished successfully installing and configuring GUI Extension " + $guiExtensionName )
}

function GuiExtensionExistsInIIS
{
    param (
        [parameter(Mandatory=$true)][string]$extensionName
    )

    [string]$path = 'IIS:\Sites\SDL Tridion\WebUI\Editors\' + $extensionName
    if (Test-Path $path) 
    {
        return 1
    }
    else
    {
        return 0
    }
} 

function GetGuiExtensionListFromConfig
{

} 

function ExtractFiles{
    param (
        [string]$sourcefile
    )
    
    #************* Unzip files ******************* 
    $shell_app=new-object -com shell.application
    if($sourcefile.EndsWith(".zip"))
    {   
	    $zip_file = $shell_app.namespace("$sourcefile")
        $destinationFolder =  $zip_file.ParentFolder 
	    Write-Verbose(" Unzipping " + $zip_file + " to " + $destinationFolder)
	    $destinationFolder.Copyhere($zip_file.items())
    }
}

function Get-IISTridionSitePath($tridionVer){
    $vpath = 'IIS:\Sites\SDL Tridion ' + $tridionVer
    if(!(Test-Path $vpath -PathType Container))
    {        
        filter ShowTridionFolder 
        {
          $filename = $_.Name
          if ($filename -like "SDL Tridion")
          { 
            return $_.Name
          }
        }

        $tridionFolder = Get-ChildItem IIS:\Sites | ShowTridionFolder | Select-Object -First 1
        $vpath = 'IIS:\Sites\' + $tridionFolder
    }
    return $vpath;
}

InstallGuiExtension
