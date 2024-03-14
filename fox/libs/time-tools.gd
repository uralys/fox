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
