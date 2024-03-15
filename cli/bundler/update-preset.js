// -----------------------------------------------------------------------------

import chalk from 'chalk';
import { androidExtension } from './export.js';
import { toVersionNumber } from './versioning.js';

// -----------------------------------------------------------------------------

const MAC_OSX = 'Mac OSX';
const IOS = 'iOS';
const ANDROID = 'Android';

// -----------------------------------------------------------------------------

const updateOptions = (preset, key, value) => {
  preset.options[key] = value;
  console.log(`  - ${chalk.bold(key)}=${chalk.yellow.italic(value)}`);
};

const updateMain = (preset, key, value) => {
  preset[key] = value;
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

const updateAndroidPreset = (env, preset, bundle, bundleId, applicationName, bundleName) => {
  console.log(`main:`);
  updateMain(preset, 'export_path', `_build/android/${bundleName}${androidExtension(env)}`);
  console.log(`options:`);

  const _applicationName = `${applicationName}${env === 'release' ? '' : `(${env})`}`;
  updateOptions(preset, 'package/name', _applicationName);

  const packageUIDKey = 'package/unique_name';
  const packageUID = (bundle[ANDROID] && bundle[ANDROID][packageUIDKey]) || bundle.uid;
  updateOptions(preset, packageUIDKey, packageUID);

  if (env === 'release' && bundle[ANDROID]['keystore/release_user']) {
    updateOptions(preset, 'keystore/release_user', bundle[ANDROID]['keystore/release_user']);
  }

  updateIcons(preset, bundleId);
};

// -----------------------------------------------------------------------------

const updateIOSPreset = (env, preset, bundle, bundleId, applicationName, bundleName) => {
  console.log(`main:`);
  updateMain(preset, 'export_path', `_build/iOS/${bundleName}.ipa`);
  console.log(`options:`);

  updateOptions(preset, 'application/name', applicationName);

  const packageUID = (bundle[IOS] && bundle[IOS]['application/bundle_identifier']) || bundle.uid;
  updateOptions(preset, 'application/bundle_identifier', packageUID);

  updateIcons(preset, bundleId);
};

// -----------------------------------------------------------------------------

const updateMacOSPreset = (env, preset, bundle, bundleId, applicationName) => {
  console.log(`main:`);
  updateMain(preset, 'export_path', `_build/macOS/${bundleName}`);
  console.log(`options:`);

  updateOptions(preset, 'application/name', applicationName);

  const packageUID = (bundle[IOS] && bundle[IOS]['application/bundle_identifier']) || bundle.uid;
  updateOptions(preset, 'application/bundle_identifier', packageUID);

  updateIcons(preset, bundleId);
};

// -----------------------------------------------------------------------------

export const updateVersionInPreset = (preset, newVersion) => {
  const {platform, name} = preset;
  console.log('> updating version for', name);

  switch (platform) {
    case ANDROID:
      updateOptions(preset, 'version/code', toVersionNumber(newVersion));
      updateOptions(preset, 'version/name', newVersion);
      break
    case IOS:
    case MAC_OSX:
      updateOptions(preset, 'application/short_version', newVersion);
      updateOptions(preset, 'application/version', newVersion);
      break
  }
};

// -----------------------------------------------------------------------------

const updatePreset = (bundleId, env, coreConfig, preset, bundle) => {
  const {platform} = preset;
  console.log('⚙️  updating the preset:');
  const {subtitle} = bundle;

  const applicationName = subtitle
    ? `${coreConfig.applicationName}: ${subtitle}`
    : coreConfig.applicationName;

  const bundleName = `${bundleId}${env === 'release' ? '' : `-${env}`}`;

  switch (platform) {
    case ANDROID:
      updateAndroidPreset(env, preset, bundle, bundleId, applicationName, bundleName);
      break;
    case IOS:
      updateIOSPreset(env, preset, bundle, bundleId, applicationName, bundleName);
      break;
    case MAC_OSX:
      updateMacOSPreset(env, preset, bundle, bundleId, applicationName, bundleName);
      break;
    default:
      console.log(`\n> platform ${platform} has no preset specificity.`);
      console.log(`> applying default preset options:`);
      updateOptions(preset, 'application/name', applicationName);
  }

  console.log('✅ preset successfully updated.');

  return {
    applicationName,
    bundleName
  };
};

// -----------------------------------------------------------------------------

export default updatePreset;
