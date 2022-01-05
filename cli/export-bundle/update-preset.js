// -----------------------------------------------------------------------------

const chalk = require('chalk');
const toVersionNumber = require('./version-number');

// -----------------------------------------------------------------------------

const MAC_OSX = 'Mac OSX';
const IOS = 'iOS';
const ANDROID = 'Android';

// -----------------------------------------------------------------------------

const updateOptions = (preset, key, value) => {
  preset.options[key] = value;
  console.log(`  - ${chalk.bold(key)}=${chalk.yellow.italic(value)}`);
};

// -----------------------------------------------------------------------------

const updateIcons = (preset, bundleId) => {
  Object.keys(preset.options).forEach((key) => {
    if (key.includes('icon')) {
      const newIcon = preset.options[key].replace(
        /generated\/.+\/icons/g,
        `generated/${bundleId}/icons`
      );

      updateOptions(preset, key, newIcon);
    }
  });
};

// -----------------------------------------------------------------------------

const updateAndroidPreset = (preset, bundle, bundleId, applicationName, newVersion) => {
  updateOptions(preset, 'package/name', applicationName);

  const packageUIDKey = 'package/unique_name';
  const packageUID = (bundle[ANDROID] && bundle[ANDROID][packageUIDKey]) || bundle.uid;
  updateOptions(preset, packageUIDKey, packageUID);

  if (bundle[ANDROID]['keystore/release_user']) {
    updateOptions(preset, 'keystore/release_user', bundle[ANDROID]['keystore/release_user']);
  }

  if (newVersion) {
    updateOptions(preset, 'version/code', toVersionNumber(newVersion));
    updateOptions(preset, 'version/code', newVersion);
  }

  updateIcons(preset, bundleId);
};

// -----------------------------------------------------------------------------

const updateIOSPreset = (preset, bundle, bundleId, applicationName, newVersion) => {
  updateOptions(preset, 'application/name', applicationName);

  const packageUIDKey = 'application/identifier';
  const packageUID = (bundle[IOS] && bundle[IOS][packageUIDKey]) || bundle.uid;
  updateOptions(preset, packageUIDKey, packageUID);

  if (newVersion) {
    updateOptions(preset, 'application/short_version', newVersion);
    updateOptions(preset, 'application/version', newVersion);
  }

  updateIcons(preset, bundleId);
};

// -----------------------------------------------------------------------------

const updateMacOSPreset = (preset, bundle, bundleId, applicationName, newVersion) => {
  updateOptions(preset, 'application/name', applicationName);

  const packageUIDKey = 'application/identifier';
  const packageUID = (bundle[IOS] && bundle[IOS][packageUIDKey]) || bundle.uid;
  updateOptions(preset, packageUIDKey, packageUID);

  if (newVersion) {
    updateOptions(preset, 'application/short_version', newVersion);
    updateOptions(preset, 'application/version', newVersion);
  }

  updateIcons(preset, bundleId);
};

// -----------------------------------------------------------------------------

const updatePreset = (bundleId, coreConfig, preset, bundle, newVersion) => {
  const {platform} = preset;
  console.log('⚙️  updating the preset:');
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
    default:
      console.log(`\nplatform ${platform} is not handled.`);
      console.log(chalk.red.bold('🔴 failed'));
  }
};

// -----------------------------------------------------------------------------

module.exports = updatePreset;
