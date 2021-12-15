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
