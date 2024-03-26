# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

class_name TimeTools

# ------------------------------------------------------------------------------

# returns a yyyymmdd number: e.g: 20240820
static func dateTimeToYYYYMMDDNumber(datetime: Dictionary):
  var yyyymmdd = (
    str(datetime.year)
    + str(datetime.month).pad_zeros(2)
    + str(datetime.day).pad_zeros(2)
  )

  return int(yyyymmdd)

# ------------------------------------------------------------------------------

# returns a yyyymm number: e.g: 202408
static func dateTimeToYYYYMMNumber(datetime: Dictionary):
  var yyyymm = (
    str(datetime.year)
    + str(datetime.month).pad_zeros(2)
  )

  return int(yyyymm)

# ------------------------------------------------------------------------------

# e.g: 2024-03-13 10:29
static func dateTimeToReadableDate(datetime: Dictionary):
  var readableDate = (
    str(datetime.year) +  '-'
    + str(datetime.month).pad_zeros(2)+ '-'
    + str(datetime.day).pad_zeros(2) + ' '
    + str(datetime.hour).pad_zeros(2) + ':'
    + str(datetime.minute).pad_zeros(2)
  )

  return readableDate

# ------------------------------------------------------------------------------

static func getTimeRemainingForSeason():
  var timestampUTCSec = Time.get_unix_time_from_system()
  var datetime = Time.get_datetime_dict_from_unix_time(timestampUTCSec)

  datetime.month += 1
  if datetime.month > 12:
      datetime.month = 1
      datetime.year += 1

  datetime.day = 1
  datetime.hour = 0
  datetime.minute = 0
  datetime.second = 0

  var nextSeasonStartTimestamp = Time.get_unix_time_from_datetime_dict(datetime)
  var diffSec = int(floor(nextSeasonStartTimestamp - timestampUTCSec))

  @warning_ignore("integer_division")
  var days = int(diffSec / (60 * 60 * 24))
  @warning_ignore("integer_division")
  var hours = int((diffSec % (60 * 60 * 24)) / (60 * 60))
  @warning_ignore("integer_division")
  var minutes = int((diffSec % (60 * 60)) / 60)
  var seconds = int(diffSec) % 60


  return {
    nbDays = days,
    timeBeforeMidnight = (
     str(hours).pad_zeros(2) + ':'
    + str(minutes).pad_zeros(2) + ':'
    + str(seconds).pad_zeros(2))
  }

