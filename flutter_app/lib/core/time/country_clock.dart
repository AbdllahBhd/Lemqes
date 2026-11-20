/// Fixed UTC offsets of the supported country timezones. Algeria has had no
/// DST since 1981, so a table is exact; a new country adds a row here.
const _offsets = <String, Duration>{'Africa/Algiers': Duration(hours: 1)};

/// The wall-clock time in [timezone] at the instant [utcNow].
///
/// The result is a UTC-flagged [DateTime] whose fields read as the country's
/// wall clock (weekday, hour, day), whatever the device's own zone is. Do not
/// compare it with real instants. Throws [ArgumentError] for an unknown zone.
DateTime countryNow(String timezone, DateTime utcNow) {
  final offset = _offsets[timezone];
  if (offset == null) {
    throw ArgumentError.value(timezone, 'timezone', 'unknown timezone');
  }
  return utcNow.toUtc().add(offset);
}
