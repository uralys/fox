// -----------------------------------------------------------------------------

const MAC_OSX = 'Mac OSX';
const IOS = 'iOS';
const ANDROID = 'Android';

// -----------------------------------------------------------------------------

const updateIcons = (preset, bundleId) => {
  Object.keys(preset.options).forEach((key) => {
    if (key.includes('icons')) {
      preset.options[key] = preset.options[key].replace(
        /generated\/.+\/icons/g,
        `generated/${bundleId}/icons`
      );
    }
  });
};

// -----------------------------------------------------------------------------

const updateAndroidPreset = (preset, bundle, bundleId, applicationName) => {
  preset.options['package/name'] = applicationName;

  const packageUIDKey = 'package/unique_name';
  preset.options[packageUIDKey] = (bundle[ANDROID] && bundle[ANDROID][packageUIDKey]) || bundle.uid;

  const keystoreUserKey =
    preset.options['keystore/release_user'].length > 0
      ? 'keystore/release_user'
      : 'keystore/debug_user';

  preset.options[keystoreUserKey] =
    (bundle[ANDROID] && bundle[ANDROID][keystoreUserKey]) || bundle.uid;

  updateIcons(preset, bundleId);
};

// -----------------------------------------------------------------------------

const updateIOSPreset = (preset, bundle, bundleId, applicationName) => {
  preset.options['application/name'] = applicationName;

  const packageUIDKey = 'application/identifier';
  preset.options[packageUIDKey] = (bundle[IOS] && bundle[IOS][packageUIDKey]) || bundle.uid;

  updateIcons(preset, bundleId);
};

// -----------------------------------------------------------------------------

const updateMacOSPreset = (preset, bundle, bundleId, applicationName) => {
  preset.options['application/name'] = applicationName;

  const packageUIDKey = 'application/identifier';
  preset.options[packageUIDKey] = (bundle[MAC_OSX] && bundle[MAC_OSX][packageUIDKey]) || bundle.uid;

  preset.options['application/icon'] = preset.options['application/icon'].replace(
    /generated\/.+\/icons/g,
    `generated/${bundleId}/icons`
  );
};

// -----------------------------------------------------------------------------

const updatePreset = (bundleId, coreConfig, preset, bundle) => {
  const {platform} = preset;
  console.log('updatePreset with bundle settings:', {bundle});
  const {subtitle} = bundle;

  const applicationName = subtitle
    ? `${coreConfig.applicationName}: ${subtitle}`
    : coreConfig.applicationName;

  switch (platform) {
    case ANDROID:
      updateAndroidPreset(preset, bundle, bundleId, applicationName);
      break;
    case IOS:
      updateIOSPreset(preset, bundle, bundleId, applicationName);
      break;
    case MAC_OSX:
      updateMacOSPreset(preset, bundle, bundleId, applicationName);
      break;
  }
};

// -----------------------------------------------------------------------------

module.exports = updatePreset;
