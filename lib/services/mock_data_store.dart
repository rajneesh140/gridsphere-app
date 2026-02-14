class MockDataStore {
  static final MockDataStore _instance = MockDataStore._internal();
  factory MockDataStore() => _instance;
  MockDataStore._internal();

  final Map<String, Map<String, dynamic>> _deviceData = {};

  Map<String, dynamic> getOrGenerateData(String deviceId) {
    if (_deviceData.containsKey(deviceId)) {
      return _deviceData[deviceId]!;
    }

    // --- HARDCODED VALUES (No Random) ---

    // 1. Fixed History Arrays (24h)
    // Creating a static pattern for the charts
    List<double> pmHistory = [
      45.0, 48.0, 50.0, 52.0, 55.0, 53.0, 50.0, 48.0,
      46.0, 45.0, 60.0, 75.0, 80.0, 70.0, 65.0, 62.0,
      58.0, 55.0, 52.0, 50.0, 48.0, 46.0, 45.0, 44.0
    ]; // Ends at 44.0

    List<double> memsHistory = [
      20.0, 20.0, 22.0, 25.0, 30.0, 40.0, 60.0, 80.0,
      90.0, 85.0, 80.0, 70.0, 60.0, 50.0, 40.0, 30.0,
      25.0, 20.0, 20.0, 15.0, 15.0, 10.0, 10.0, 10.0
    ];

    List<double> tempHistory = [
      22.0, 22.5, 23.0, 23.5, 24.0, 25.0, 26.5, 28.0,
      29.5, 30.0, 30.5, 30.0, 29.0, 28.0, 27.0, 26.0,
      25.0, 24.5, 24.0, 23.5, 23.0, 22.5, 22.0, 22.0
    ];

    // 2. Fixed Current Values
    // These match the logic you likely want to demonstrate (e.g., Moderate Risk)

    // Weather / General
    double airTemp = 28.5;
    double humidity = 45.0;
    double windSpeed = 3.5; // Moderate breeze
    double rainfall = 0.0;
    double light = 5500.0;
    double pressure = 1012.0;

    // Soil / Agriculture
    double soilTemp = 24.0;
    double soilMoisture = 35.0;
    String leafWetness = "Dry";

    // Cement / Industrial
    double pm25 = 68.0; // Slightly elevated for demo
    double tvoc = 420.0;
    double mems = 65.0; // Active machinery
    double windDirection = 45.0; // Points to "Crusher" sector (30-80)

    final data = {
      // Shared keys
      'air_temp': airTemp,
      'humidity': humidity,
      'wind_speed': windSpeed,
      'wind': windSpeed,
      'rainfall': rainfall,
      'light_intensity': light,
      'pressure': pressure,

      // Agri keys
      'soil_temp': soilTemp,
      'soil_moisture': soilMoisture,
      'leaf_wetness': leafWetness,
      'surface_temp': 29.0,
      'surface_humidity': 40.0,
      'depth_temp': soilTemp,
      'depth_humidity': soilMoisture,

      // Cement keys
      'pm25': pm25,
      'tvoc': tvoc,
      'memsCurrent': mems,
      'windDirection': windDirection,

      // Histories (for charts)
      'pmHistory': pmHistory,
      'memsHistory': memsHistory,
      'tempHistory': tempHistory,

      // Lists for Dashboard Charts
      'history_air_temp': tempHistory,
      'history_humidity': List.filled(24, 45.0), // Flat line for simple chart
      'history_wind': List.filled(24, 3.5),
    };

    _deviceData[deviceId] = data;
    return data;
  }

  void refresh(String deviceId) {
    _deviceData.remove(deviceId);
  }
}