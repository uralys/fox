################################################################################
## generates icons from a base image
## requires https://www.imagemagick.org/script/index.php
## to enable "convert" command
## OSX: brew install imagemagick
################################################################################
## script iteration from cherry 🍒 > https://github.com/chrisdugne/cherry/blob/master/prepare-icons.sh
################################################################################

#!/bin/sh
inputFile=$PWD/assets/icons/icon-square-1200x1200.png
outputPath=$PWD/assets/icons/generated

echo '----------------------------'
echo '🦊 starting Icons generation'

if [ ! -f "$inputFile" ]
then
  echo "❌ [error] File $inputFile does not exist"
  exit
else
  echo "using: $inputFile"
fi

if [ ! -d  "$outputPath" ]
then
  echo "❎ Folder $outputPath does not exist, creating it"
  mkdir $outputPath
fi

echo "output: $outputPath"
echo '----------------------------'

## https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/AppIconType.html
echo '> creating icons...'
convert "$inputFile" -resize '20x20'      -unsharp 1x4 "$outputPath/icon-20x20.png"
convert "$inputFile" -resize '29x29'      -unsharp 1x4 "$outputPath/icon-29x29.png"
convert "$inputFile" -resize '40x40'      -unsharp 1x4 "$outputPath/icon-40x40.png"
convert "$inputFile" -resize '58x58'      -unsharp 1x4 "$outputPath/icon-58x58.png"
convert "$inputFile" -resize '60x60'      -unsharp 1x4 "$outputPath/icon-60x60.png"
convert "$inputFile" -resize '76x76'      -unsharp 1x4 "$outputPath/icon-76x76.png"
convert "$inputFile" -resize '80x80'      -unsharp 1x4 "$outputPath/icon-80x80.png"
convert "$inputFile" -resize '87x87'      -unsharp 1x4 "$outputPath/icon-87x87.png"
convert "$inputFile" -resize '120x120'    -unsharp 1x4 "$outputPath/icon-120x120.png"
convert "$inputFile" -resize '152x152'    -unsharp 1x4 "$outputPath/icon-152x152.png"
convert "$inputFile" -resize '167x167'    -unsharp 1x4 "$outputPath/icon-167x167.png"
convert "$inputFile" -resize '180x180'    -unsharp 1x4 "$outputPath/icon-180x180.png"
convert "$inputFile" -resize '1024x1024'  -unsharp 1x4 "$outputPath/icon-1024x1024.png"

echo '✅ done!'
tree $outputPath
