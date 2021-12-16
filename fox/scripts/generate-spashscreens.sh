################################################################################
## generates splashscreens from a base image
## requires https://www.imagemagick.org/script/index.php
## to enable "convert" command
## OSX: brew install imagemagick
################################################################################

#!/bin/sh
inputFile=$PWD/assets/icons/base-splashscreen.png
outputPath=$PWD/assets/icons/generated

echo '----------------------------'
echo '🦊 starting splashscreen generation'

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

echo '> creating...'
convert "$inputFile" -gravity center  -background '#181818' -extent 2436x1125 "$outputPath/splashscreen-2436x1125.png"
convert "$inputFile" -gravity center  -background '#181818' -extent 2208x1242 "$outputPath/splashscreen-2208x1242.png"
convert "$inputFile" -gravity center  -background '#181818' -extent 1024x768  "$outputPath/splashscreen-1024x768.png"
convert "$inputFile" -gravity center  -background '#181818' -extent 2048x1536 "$outputPath/splashscreen-2048x1536.png"

echo '✅ done!'
tree $outputPath
