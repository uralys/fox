# Android

Exporting for Android: <https://docs.godotengine.org/en/stable/getting_started/workflow/export/exporting_for_android.html#doc-exporting-for-android>

## debug key

generate debug key for godot:

```sh
> keytool -keyalg RSA -genkeypair -v -alias YOUR_ALIAS -keystore android.debug.keystore -validity 9999 -deststoretype pkcs12 -keypass YOUR_PASSWORD
```

replace in the preset options:

```ini
keystore/debug_user="YOUR_ALIAS"
keystore/debug_password="YOUR_PASSWORD"
```

## icons

In `assets/android` you'll find the adaptive icons template from <https://cyrilmottier.com/2017/07/06/adaptive-icon-template/>

## apk for debug

### build apk from cli

```sh
> /Applications/Apps/Godot.app/Contents/MacOS/Godot --export-debug "Android Debug" --headless
```

### manifest from apk

```sh
> aapt dump badging _build/android/lockeyland.apk
```

```sh
> which aapt
aapt: aliased to ~/Library/Android/sdk/build-tools/32.0.0/aapt2
```

## aab for releases

### build aab from cli

```sh
> /Applications/Apps/Godot.app/Contents/MacOS/Godot --export-debug "Android Release" --headless
```

### manifest from aab

```sh
> brew install bundletool
```

```sh
> bundletool dump manifest --bundle _build/android/lockeyland.aab --xpath /manifest/@android:versionName
1.0.0
```

```sh
> bundletool dump manifest --bundle _build/android/lockeyland.aab --xpath /manifest/@android:versionCode
10000
```

## install playstore on emulators

all steps: <https://proandroiddev.com/install-google-play-store-in-an-android-emulator-82cd183fefed>

1 - download `Phonesky.apk`
2 - `emulator @pixel-api-21 -writable-system`
3 - `adb remount`
4 - `adb push ~/path/to/Phonesky.apk /system/priv-app/`
5 - `adb shell stop && adb shell start`

## intall apk on emulator

1 - `emulator @pixel-api-21 -no-snapshot -writable-system`
2 - `fox export` an android debug preset
3 - `adb uninstall com.uralys.xxx`
4 - `adb install -r ~/path/to/your.apk`
5 - `adb logcat -s godot`

--> repeat from `2` to `5` on every test

## IAP

- configure to build with gradle: it will generate a root `android` folder
- install android plugins within `android/plugins`

```sh
android/plugins
├── GodotGooglePlayBilling.x.x.x.release.aar
└── GodotGooglePlayBilling.gdap
```

note: currently using `godot-lib.4.1.3.stable.template_release.aar` and building `assembleRelease` from Android Studio

to test android IAP:

- `fox export > select an android release preset` to generate the `.aab`
- create an intern release
- add a product
- add a tester and send invite link to internal Play Store
- connect to PlayStore with this tester account
- Accept the invitation through the link

then the test account can see the SKU even from `debug.apk` generated with `fox export > android debug preset` manually installed with `adb`.

API reference and examples: <https://docs.godotengine.org/en/stable/tutorials/platform/android/android_in_app_purchases.html>
