:: CodeProject.AI Server 
::
:: Create packages script for Windows
::
:: This script will look for a package.bat script each of the modules directories
:: and execute that script. The package.bat script is responsible for packaging
:: up everything needed for the module to be ready to install.

@echo off
REM cls
setlocal enabledelayedexpansion

:: verbosity can be: quiet | info | loud
set verbosity=quiet

:: Show output in wild, crazy colours
set useColor=true

:: Set this to false (or call script with --no-dotnet) to exclude .NET packages
:: This saves time to allow for quick packaging of the easier, non-compiled modules
set includeDotNet=true

:: Basic locations

:: The path to the directory containing the setup script. Will end in "\"
set setupScriptDirPath=%~dp0

:: The name of the source directory
set srcDir=src

:: The name of the dir, within the current directory, where install assets will
:: be downloaded
set downloadDir=downloads

:: The name of the dir holding the downloaded/sideloaded backend analysis services
set modulesDir=modules


:: Override some values via parameters ::::::::::::::::::::::::::::::::::::::::

:param_loop
    set arg_name=%~1
    set arg_value=%~2
    if not "!arg_name!" == "" (
        if not "!arg_name:--no-color=!" == "!arg_name!" set useColor=false
        if not "!arg_name:--no-dotnet=!" == "!arg_name!" set includeDotNet=false
        if not "!arg_name:--path-to-setup=!" == "!arg_name!" (
            set setupScriptDirPath=!arg_value!
            shift
        )
    )
    shift
if not "!arg_name!"=="" goto param_loop

:: In Development, this script is in the /src folder. In Production there is no
:: /src folder; everything is in the root folder. So: go to the folder
:: containing this script and check the name of the parent folder to see if
:: we're in dev or production.
pushd "!setupScriptDirPath!"
for /f "delims=\" %%a in ("%cd%") do @set setupScriptDirName=%%~nxa
popd

set executionEnvironment=Production
if /i "%setupScriptDirName%" == "%srcDir%" set executionEnvironment=Development

:: The absolute path to the setup script and the root directory. Note that
:: this script (and the SDK folder) is either in the /src dir or the root dir
pushd "!setupScriptDirPath!"
set sdkScriptsDirPath=%cd%\SDK\Scripts
if /i "%executionEnvironment%" == "Development" cd ..
set rootDirPath=%cd%
popd

set appRootDirPath=!setupScriptDirPath!

:: Platform can define where things are located :::::::::::::::::::::::::::::::

:: The location of directories relative to the root of the solution directory
set modulesDirPath=!appRootDirPath!!modulesDir!
set downloadDirPath=!appRootDirPath!!downloadDir!

:: Let's go
if /i "!useColor!" == "true" call "!sdkScriptsDirPath!\utils.bat" setESC
if /i "!executionEnvironment!" == "Development" (
    set scriptTitle=          Creating CodeProject.AI Module Downloads
) else (
    writeLine "Can't run in Production. Exiting" "Red"
    goto:eof
)

set lineWidth=70

call "!sdkScriptsDirPath!\utils.bat" WriteLine 
call "!sdkScriptsDirPath!\utils.bat" WriteLine "!scriptTitle!" "DarkYellow" "Default" !lineWidth!
call "!sdkScriptsDirPath!\utils.bat" WriteLine 
call "!sdkScriptsDirPath!\utils.bat" WriteLine "========================================================================" "DarkGreen" 
call "!sdkScriptsDirPath!\utils.bat" WriteLine 
call "!sdkScriptsDirPath!\utils.bat" WriteLine "                   CodeProject.AI Packager                             " "DarkGreen" 
call "!sdkScriptsDirPath!\utils.bat" WriteLine 
call "!sdkScriptsDirPath!\utils.bat" WriteLine "========================================================================" "DarkGreen" 
call "!sdkScriptsDirPath!\utils.bat" WriteLine 


if /i "%verbosity%" neq "quiet" (
    call "!sdkScriptsDirPath!\utils.bat" WriteLine 
    call "!sdkScriptsDirPath!\utils.bat" WriteLine "executionEnvironment = !executionEnvironment!" !color_mute!
    call "!sdkScriptsDirPath!\utils.bat" WriteLine "appRootDirPath       = !appRootDirPath!"       !color_mute!
    call "!sdkScriptsDirPath!\utils.bat" WriteLine "setupScriptDirPath   = !setupScriptDirPath!"   !color_mute!
    call "!sdkScriptsDirPath!\utils.bat" WriteLine "sdkScriptsDirPath    = !sdkScriptsDirPath!"    !color_mute!
    call "!sdkScriptsDirPath!\utils.bat" WriteLine "modulesDirPath       = !modulesDirPath!"       !color_mute!
    call "!sdkScriptsDirPath!\utils.bat" WriteLine
)

:: And off we go...

set success=true

REM  Walk through the modules directory and call the package script in each dir
rem Make this just "for /d %%D in ("%modulesDirPath%") do ("

for /f "delims=" %%a in ('dir /a:d /b "!modulesDirPath!"') do (

    set packageModuleDirName=%%~nxa
    set packageModuleId=!packageModuleDirName!
    set packageModuleDirPath=!modulesDirPath!\!packageModuleDirName!

    if /i "%verbosity%" neq "quiet" (
        call "!sdkScriptsDirPath!\utils.bat" WriteLine "packageModuleDirPath           = !packageModuleDirPath!" !color_mute!
    )

    if exist "!packageModuleDirPath!\package.bat" (

        set doPackage=true

        if "!includeDotNet!" == "false" if "!packageModuleId!" == "ObjectDetectionNet" set doPackage=false
        if "!includeDotNet!" == "false" if "!packageModuleId!" == "PortraitFilter"     set doPackage=false
        if "!includeDotNet!" == "false" if "!packageModuleId!" == "SentimentAnalysis"  set doPackage=false

        if "!doPackage!" == "false" (
            call "!sdkScriptsDirPath!\utils.bat" WriteLine "Skipping packaging module !packageModuleId!..." "Red"
        ) else (

            pushd "!packageModuleDirPath!" 

            REM Read the version from the modulesettings.json file and then pass this 
            REM version to the package.bat file.
            call "!sdkScriptsDirPath!\utils.bat" GetValueFromModuleSettings "modulesettings.json", "Version"   REM, packageVersion
            set packageVersion=!moduleSettingValue!

            call "!sdkScriptsDirPath!\utils.bat" Write "Packaging module !packageModuleId! !packageVersion!..." "White"

            rem Create module download package
            call package.bat !packageModuleId! !packageVersion!
            if errorlevel 1 call "!sdkScriptsDirPath!\utils.bat" WriteLine "Error in package.bat for !packageModuleDirName!" "Red"

            popd
            
            rem Move package into modules download cache       
            rem echo Moving !packageModuleDirPath!\!packageModuleId!-!version!.zip to !downloadDirPath!\modules\
            move /Y !packageModuleDirPath!\!packageModuleId!-!packageVersion!.zip !downloadDirPath!\modules\  >NUL 2>&1

            if errorlevel 1 (
                call "!sdkScriptsDirPath!\utils.bat" WriteLine "Error" "Red"
                set success=false
            ) else (
                call "!sdkScriptsDirPath!\utils.bat" WriteLine "Done" "DarkGreen"
            )
        )
    )
)

call "!sdkScriptsDirPath!\utils.bat" WriteLine
call "!sdkScriptsDirPath!\utils.bat" WriteLine "                Modules packaging Complete" "White" "DarkGreen" !lineWidth!
call "!sdkScriptsDirPath!\utils.bat" WriteLine

if /i "!success!" == "false" exit /b 1
