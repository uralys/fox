// -----------------------------------------------------------------------------

import {presetLogger} from '../logger.js';
import { androidExtension, getApplicationName } from './export.js';
import { toVersionNumber } from './versioning.js';

// -----------------------------------------------------------------------------

const MAC_OSX = 'Mac OSX';
const IOS = 'iOS';
const ANDROID = 'Android';

// -----------------------------------------------------------------------------

const updateOptions = (preset, key, value) => {
  preset.options[key] = value;
  presetLogger.log(`${key} = ${value}`);
};

const updateMain = (preset, key, value) => {
  preset[key] = value;
  presetLogger.log(`${key} = ${value}`);
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
  updateMain(preset, 'export_path', `_build/android/${bundleName}${androidExtension(env)}`);

  updateOptions(preset, 'package/name', applicationName);

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
  updateMain(preset, 'export_path', `_build/iOS/${bundleName}.ipa`);

  updateOptions(preset, 'application/name', applicationName);

  const packageUID = (bundle[IOS] && bundle[IOS]['application/bundle_identifier']) || bundle.uid;
  updateOptions(preset, 'application/bundle_identifier', packageUID);

  updateIcons(preset, bundleId);
};

// -----------------------------------------------------------------------------

const updateMacOSPreset = (env, preset, bundle, bundleId, applicationName) => {
  updateMain(preset, 'export_path', `_build/macOS/${bundleName}`);

  updateOptions(preset, 'application/name', applicationName);

  const packageUID = (bundle[IOS] && bundle[IOS]['application/bundle_identifier']) || bundle.uid;
  updateOptions(preset, 'application/bundle_identifier', packageUID);

  updateIcons(preset, bundleId);
};

// -----------------------------------------------------------------------------

export const updateVersionInPreset = (preset, newVersion) => {
  const {platform, name} = preset;
  presetLogger.log(`Updating version for ${name}`);

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
  presetLogger.log(`Updating ${platform} preset`);

  const _applicationName = getApplicationName(coreConfig, bundle);

  const applicationName = `${_applicationName}${env === 'release' ? '' : `(${env})`}`;
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
      presetLogger.warn(`Platform ${platform} has no preset specificity, applying defaults`);
      updateOptions(preset, 'application/name', applicationName);
  }

  presetLogger.success('Preset updated');

  return {
    applicationName,
    bundleName
  };
};

// -----------------------------------------------------------------------------

export default updatePreset;
