// -----------------------------------------------------------------------------

const toVersionNumber = require('./version-number');

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

const updateAndroidPreset = (preset, bundle, bundleId, applicationName, newVersion) => {
  preset.options['package/name'] = applicationName;

  const packageUIDKey = 'package/unique_name';
  preset.options[packageUIDKey] = (bundle[ANDROID] && bundle[ANDROID][packageUIDKey]) || bundle.uid;

  if (bundle[ANDROID]['keystore/release_user']) {
    preset.options['keystore/release_user'] = bundle[ANDROID]['keystore/release_user'];
  }

  updateIcons(preset, bundleId);

  if (newVersion) {
    preset.options['version/code'] = toVersionNumber(newVersion);
    preset.options['version/name'] = newVersion;
  }
};

// -----------------------------------------------------------------------------

const updateIOSPreset = (preset, bundle, bundleId, applicationName, newVersion) => {
  preset.options['application/name'] = applicationName;

  const packageUIDKey = 'application/identifier';
  preset.options[packageUIDKey] = (bundle[IOS] && bundle[IOS][packageUIDKey]) || bundle.uid;

  updateIcons(preset, bundleId);

  if (newVersion) {
    preset.options['application/short_version'] = newVersion;
    preset.options['application/version'] = newVersion;
  }
};

// -----------------------------------------------------------------------------

const updateMacOSPreset = (preset, bundle, bundleId, applicationName, newVersion) => {
  preset.options['application/name'] = applicationName;

  const packageUIDKey = 'application/identifier';
  preset.options[packageUIDKey] = (bundle[MAC_OSX] && bundle[MAC_OSX][packageUIDKey]) || bundle.uid;

  preset.options['application/icon'] = preset.options['application/icon'].replace(
    /generated\/.+\/icons/g,
    `generated/${bundleId}/icons`
  );

  if (newVersion) {
    preset.options['application/short_version'] = newVersion;
    preset.options['application/version'] = newVersion;
  }
};

// -----------------------------------------------------------------------------

const updatePreset = (bundleId, coreConfig, preset, bundle, newVersion) => {
  const {platform} = preset;
  console.log('⚙️  updating the preset...');
  const {subtitle} = bundle;

  const applicationName = subtitle
    ? `${coreConfig.applicationName}: ${subtitle}`
    : coreConfig.applicationName;

  switch (platform) {
    case ANDROID:
      updateAndroidPreset(preset, bundle, bundleId, applicationName, newVersion);
      break;
    case IOS:
      updateIOSPreset(preset, bundle, bundleId, applicationName, newVersion);
      break;
    case MAC_OSX:
      updateMacOSPreset(preset, bundle, bundleId, applicationName, newVersion);
      break;
  }
};

// -----------------------------------------------------------------------------

module.exports = updatePreset;
