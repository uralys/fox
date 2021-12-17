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
> /Applications/Apps/Godot.app/Contents/MacOS/Godot --export-debug "Android Debug" --no-window
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
> /Applications/Apps/Godot.app/Contents/MacOS/Godot --export-debug "Android Release" --no-window
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
