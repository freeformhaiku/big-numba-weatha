import Foundation

// MARK: - App Models

/// Temperature unit preference
enum TemperatureUnit: String, Codable {
    case celsius = "celsius"
    case fahrenheit = "fahrenheit"
    
    var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
    
    var apiValue: String {
        return self.rawValue
    }
}

/// Represents weather data for a single day
struct DayWeather: Identifiable {
    let id = UUID()
    let date: Date
    let highTemp: Int
    let lowTemp: Int
    let currentTemp: Int?  // Only available for today
    let condition: WeatherCondition
}

/// Weather conditions with associated icons
/// To use custom PNG icons:
/// 1. Add images to Assets.xcassets (e.g., "weather-sunny", "weather-cloudy", etc.)
/// 2. Change useCustomIcons to true
/// 3. The customIconName will be used instead of SF Symbols
enum WeatherCondition: String, CaseIterable {
    case sunny
    case cloudy
    case partlyCloudy
    case rainy
    case snowy
    case sleet        // rain and snow mix
    case stormy
    case foggy
    
    /// Set to true when you've added custom icons to Assets.xcassets
    static let useCustomIcons = false
    
    /// SF Symbol name (used when useCustomIcons is false)
    var sfSymbolName: String {
        switch self {
        case .sunny:       return "sun.max.fill"
        case .cloudy:      return "cloud.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .rainy:       return "cloud.rain.fill"
        case .snowy:       return "cloud.snow.fill"
        case .sleet:       return "cloud.sleet.fill"
        case .stormy:      return "cloud.bolt.fill"
        case .foggy:       return "cloud.fog.fill"
        }
    }
    
    /// Custom icon name in Assets.xcassets (used when useCustomIcons is true)
    /// Name your assets: weather-sunny, weather-cloudy, etc.
    var customIconName: String {
        return "weather-\(self.rawValue)"
    }
    
    /// Returns the appropriate icon name based on useCustomIcons setting
    var iconName: String {
        return WeatherCondition.useCustomIcons ? customIconName : sfSymbolName
    }
}

/// Represents a saved city
struct SavedCity: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let region: String  // State, province, or country
    let country: String // Country name for emoji logic
    let latitude: Double
    let longitude: Double
    
    init(id: UUID = UUID(), name: String, region: String, country: String = "", latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.region = region
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }
    
    var displayName: String {
        "\(name), \(region)"
    }
    
    /// Returns true if this city is in Canada
    var isInCanada: Bool {
        country.lowercased() == "canada" || 
        region == "ON" || region == "Ontario" ||
        region == "BC" || region == "British Columbia" ||
        region == "AB" || region == "Alberta" ||
        region == "QC" || region == "Quebec" ||
        region == "MB" || region == "Manitoba" ||
        region == "SK" || region == "Saskatchewan" ||
        region == "NS" || region == "Nova Scotia" ||
        region == "NB" || region == "New Brunswick" ||
        region == "NL" || region == "Newfoundland and Labrador" ||
        region == "PE" || region == "Prince Edward Island" ||
        region == "NT" || region == "Northwest Territories" ||
        region == "YT" || region == "Yukon" ||
        region == "NU" || region == "Nunavut"
    }
}

// MARK: - Open-Meteo API Response Models
// These models match the JSON structure returned by Open-Meteo

struct WeatherAPIResponse: Codable {
    let latitude: Double
    let longitude: Double
    let timezone: String
    let currentWeather: CurrentWeather?
    let daily: DailyWeather
    
    enum CodingKeys: String, CodingKey {
        case latitude, longitude, timezone
        case currentWeather = "current_weather"
        case daily
    }
}

struct CurrentWeather: Codable {
    let temperature: Double
    let weathercode: Int
}

struct DailyWeather: Codable {
    let time: [String]
    let temperatureMax: [Double]
    let temperatureMin: [Double]
    let weathercode: [Int]
    
    enum CodingKeys: String, CodingKey {
        case time
        case temperatureMax = "temperature_2m_max"
        case temperatureMin = "temperature_2m_min"
        case weathercode
    }
}

// MARK: - Geocoding API Response Models
// For city search functionality (future feature)

struct GeocodingResponse: Codable {
    let results: [GeocodingResult]?
}

struct GeocodingResult: Codable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String
    let admin1: String?  // State/Province
    
    var region: String {
        admin1 ?? country
    }
    
    func toSavedCity() -> SavedCity {
        SavedCity(
            name: name,
            region: region,
            country: country,
            latitude: latitude,
            longitude: longitude
        )
    }
}
