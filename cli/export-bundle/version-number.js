// -----------------------------------------------------------------------------
// from https://github.com/chrisdugne/cherry/blob/master/cherry/libs/version-number.lua
// -----------------------------------------------------------------------------

const toVersionNumber = (semver) => {
  if (!semver) return 0;
  if (typeof semver !== 'string') return 0;

  const splinters = semver.split('.');

  const code = splinters.reduce((acc, splinter) => acc + splinter.padStart(2, '0'), '');
  const number = parseInt(code.padEnd(6, 0)) || 0;

  return number;
};

// -----------------------------------------------------------------------------

module.exports = toVersionNumber;

// -----------------------------------------------------------------------------
/*
  console.log('1.2.3', toVersionNumber('1.2.3'));  --> 10203
  console.log('1.2.32', toVersionNumber('1.2.32'));  --> 10232
  console.log('12.2.32', toVersionNumber('12.2.32'));  --> 120232
  console.log('12.24.32', toVersionNumber('12.24.32'));  --> 122432
  console.log('1.2', toVersionNumber('1.2'));  --> 10200
  console.log('1', toVersionNumber('1'));  --> 10000
  console.log(12, toVersionNumber(12));  --> 0
  console.log('undefined', toVersionNumber());  --> 0
  console.log(null, toVersionNumber(null));  --> 0
  console.log('whatever.not.number', toVersionNumber('whatever.not.number'));  --> 0
*/
