# iOS

## XCode

get latest version from <https://developer.apple.com/download/all/>

## cli tools

```sh
> xcode-select --install
```

## build the xcode project

```sh
/Applications/Apps/Godot.app/Contents/MacOS/Godot --export "iOS Production" --no-window
```

The build will end with an error while creating the `.ipa`.

So the `.ipa` will be created, signed and uploaded using XCode

## added auto signing option

```sh
CODE_SIGNING_ALLOWED: No
```

from <https://stackoverflow.com/a/55963713/959219>

## create the archive

@todo migrate screenshots here from <https://github.com/chrisdugne/thekeep/blob/master/uralys/projects/cherry/ios.md>
