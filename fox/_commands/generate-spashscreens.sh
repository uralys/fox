################################################################################
## generates splashscreens from a base image
## requires https://www.imagemagick.org/script/index.php
## to enable "convert" command
## OSX: brew install imagemagick
################################################################################

#!/bin/sh
inputFile=$PWD/_release/images/base-splashscreen.png
outputPath=$PWD/_release/generated
color="#181818"

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

echo '> creating landscape launch screens...'
convert "$inputFile" -gravity center -background $color -extent 2436x1125 "$outputPath/splashscreen-2436x1125.png"
convert "$inputFile" -gravity center -background $color -extent 2208x1242 "$outputPath/splashscreen-2208x1242.png"
convert "$inputFile" -gravity center -background $color -extent 1024x768  "$outputPath/splashscreen-1024x768.png"
convert "$inputFile" -gravity center -background $color -extent 2048x1536 "$outputPath/splashscreen-2048x1536.png"

echo '> creating portrait launch screens...'
convert "$inputFile" -gravity center -background $color -extent 640x960 "$outputPath/splashscreen-640x960.png"
convert "$inputFile" -gravity center -background $color -extent 640x1136 "$outputPath/splashscreen-640x1136.png"
convert "$inputFile" -gravity center -background $color -extent 750x1334 "$outputPath/splashscreen-750x1334.png"
convert "$inputFile" -gravity center -background $color -extent 1125x2436 "$outputPath/splashscreen-1125x2436.png"
convert "$inputFile" -gravity center -background $color -extent 768x1024 "$outputPath/splashscreen-768x1024.png"
convert "$inputFile" -gravity center -background $color -extent 1536x2048 "$outputPath/splashscreen-1536x2048.png"
convert "$inputFile" -gravity center -background $color -extent 1242x2208 "$outputPath/splashscreen-1242x2208.png"

echo '✅ done!'
tree $outputPath
