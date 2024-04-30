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

  @warning_ignore('INTEGER_DIVISION')
  var days = int(diffSec / (60 * 60 * 24))

  return {
    nbDays = days,
    timeBeforeMidnight = getTimeRemainingForToday()
  }

# ------------------------------------------------------------------------------

static func nbDaysInMonth(month, year):
    if month in [1, 3, 5, 7, 8, 10, 12]:
        return 31
    elif month in [4, 6, 9, 11]:
        return 30
    elif month == 2:
        if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0):
            return 29
        else:
            return 28
    else:
        return 0

# ------------------------------------------------------------------------------

static func getTimeRemainingForThisWeek():
  var timestampUTCSec = Time.get_unix_time_from_system()
  var datetime = Time.get_datetime_dict_from_unix_time(timestampUTCSec)

  var current_day_of_week = datetime.weekday  # Jour de la semaine actuel (0 est dimanche)

  var days_until_next_monday = (7 - current_day_of_week + 1) % 7
  if days_until_next_monday == 0:
      days_until_next_monday = 7  # Si aujourd'hui est lundi, le prochain lundi est dans 7 jours


  var nextMonday = datetime
  nextMonday.day += days_until_next_monday
  if nextMonday.day > nbDaysInMonth(nextMonday.month, nextMonday.year):
      nextMonday.day = nextMonday.day - nbDaysInMonth(nextMonday.month, nextMonday.year)
      nextMonday.month += 1
      if nextMonday.month > 12:
          nextMonday.month = 1
          nextMonday.year += 1

  nextMonday.hour = 0
  nextMonday.minute = 0
  nextMonday.second = 0

  var nextMondayStartTimestamp = Time.get_unix_time_from_datetime_dict(nextMonday)
  var diffSec = int(floor(nextMondayStartTimestamp - timestampUTCSec))

  @warning_ignore('INTEGER_DIVISION')
  var days = int(diffSec / (60 * 60 * 24))

  return {
    nbDays = days,
    timeBeforeMidnight = getTimeRemainingForToday()
  }

# ------------------------------------------------------------------------------

static func getTimeRemainingForToday():
  var timestampUTCSec = Time.get_unix_time_from_system()
  var datetime = Time.get_datetime_dict_from_unix_time(timestampUTCSec)

  datetime.day += 1
  if datetime.day > nbDaysInMonth(datetime.month, datetime.year):
      datetime.day = 1
      datetime.month += 1
      if datetime.month > 12:
          datetime.month = 1
          datetime.year += 1

  datetime.hour = 0
  datetime.minute = 0
  datetime.second = 0

  var nextDayStartTimestamp = Time.get_unix_time_from_datetime_dict(datetime)
  var diffSec = int(floor(nextDayStartTimestamp - timestampUTCSec))

  @warning_ignore('INTEGER_DIVISION')
  var hours = int((diffSec % (60 * 60 * 24)) / (60 * 60))
  @warning_ignore('INTEGER_DIVISION')
  var minutes = int((diffSec % (60 * 60)) / 60)
  var seconds = int(diffSec) % 60

  return (str(hours).pad_zeros(2) + ':'
    + str(minutes).pad_zeros(2) + ':'
    + str(seconds).pad_zeros(2))
