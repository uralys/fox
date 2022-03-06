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

const updateAndroidPreset = (env, preset, bundle, bundleId, applicationName, newVersion) => {
  const _applicationName = `${applicationName}${env === 'debug' ? '(debug)' : ''}`;
  updateOptions(preset, 'package/name', _applicationName);

  const packageUIDKey = 'package/unique_name';
  const packageUID = (bundle[ANDROID] && bundle[ANDROID][packageUIDKey]) || bundle.uid;
  updateOptions(preset, packageUIDKey, packageUID);

  if (env === 'production' && bundle[ANDROID]['keystore/release_user']) {
    updateOptions(preset, 'keystore/release_user', bundle[ANDROID]['keystore/release_user']);
  }

  if (newVersion) {
    updateOptions(preset, 'version/code', toVersionNumber(newVersion));
    updateOptions(preset, 'version/name', newVersion);
  }

  updateIcons(preset, bundleId);
};

// -----------------------------------------------------------------------------

const updateIOSPreset = (env, preset, bundle, bundleId, applicationName, newVersion) => {
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

const updateMacOSPreset = (env, preset, bundle, bundleId, applicationName, newVersion) => {
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

const updatePreset = (bundleId, env, coreConfig, preset, bundle, newVersion) => {
  const {platform} = preset;
  console.log('⚙️  updating the preset:');
  const {subtitle} = bundle;

  const applicationName = subtitle
    ? `${coreConfig.applicationName}: ${subtitle}`
    : coreConfig.applicationName;

  switch (platform) {
    case ANDROID:
      updateAndroidPreset(env, preset, bundle, bundleId, applicationName, newVersion);
      break;
    case IOS:
      updateIOSPreset(env, preset, bundle, bundleId, applicationName, newVersion);
      break;
    case MAC_OSX:
      updateMacOSPreset(env, preset, bundle, bundleId, applicationName, newVersion);
      break;
    default:
      console.log(`\nplatform ${platform} is not handled.`);
      console.log(chalk.red.bold('🔴 failed'));
      return;
  }

  console.log('✅ preset successfully updated.');

  return {
    applicationName
  };
};

// -----------------------------------------------------------------------------

module.exports = updatePreset;
