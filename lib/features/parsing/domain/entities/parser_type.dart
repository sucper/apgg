/// Defines the types of data parsers available in the application.
enum ParserType {
  /// A placeholder for when the parser is not yet known or assigned.
  unknown,

  /// For parsing NMEA 0183 sentences, typically from GPS devices.
  gpsNmea,

  /// For parsing autopilot-specific binary data.
  autopilotBinary,

  /// For parsing simple string or text data.
  plainText,
}
