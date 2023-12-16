# iOS

## XCode

get latest version from <https://developer.apple.com/download/all/>

## build the xcode project

```sh
fox export
```

- Select your iOS preset
- the `.ipa` will be created, you'll be able to use it with XCode

## added auto signing option

```sh
CODE_SIGNING_ALLOWED: No
```

from <https://stackoverflow.com/a/55963713/959219>

## create the archive

@todo migrate screenshots here from <https://github.com/chrisdugne/thekeep/blob/master/uralys/projects/cherry/ios.md>

## upload to appstore

<https://github.com/DrMoriarty/nativelib/blob/main/MACAPPSTORE.md>

## IAP

- install godot appstore plugin from <https://github.com/godotengine/godot-ios-plugins/releases> or <https://github.com/Makosai/godot-ios-plugins-4.x/releases> within `ios/plugins`

```sh
ios/plugins
└── inappstore
    ├── inappstore.debug.xcframework
    ├── inappstore.gdip
    └── inappstore.release.xcframework
```
