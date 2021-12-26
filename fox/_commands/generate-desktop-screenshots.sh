################################################################################
## generates splashscreens from a base image
## requires https://www.imagemagick.org/script/index.php
## to enable "convert" command
## OSX: brew install imagemagick
################################################################################

#!/bin/sh
inputFolder=$PWD/_release/raw-shots
outputPath=$PWD/_release/generated

echo '----------------------------'
echo '🦊 starting desktop screenshots generation'

if [ ! -d "$inputFolder" ]
then
  echo "❌ [error] Folder $inputFolder does not exist"
  exit
else
  echo "using: $inputFolder"
fi

if [ ! -d  "$outputPath" ]
then
  echo "❎ Folder $outputPath does not exist, creating it"
  mkdir $outputPath
fi

echo "output: $outputPath"
echo '----------------------------'

echo '> creating landscape launch screens...'
for file in $inputFolder
  do echo $file; done
# convert 1-1.png -resize 2560x1600^ -gravity center -extent 2560x1600 1-1-new.png

echo '✅ done!'
# tree $outputPath
