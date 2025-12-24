import Foundation

/// Service responsible for fetching weather data from Open-Meteo API
/// Open-Meteo is free and doesn't require an API key!
class WeatherService {
    
    // MARK: - Singleton
    static let shared = WeatherService()
    private init() {}
    
    // MARK: - API Endpoints
    private let weatherBaseURL = "https://api.open-meteo.com/v1/forecast"
    private let geocodingBaseURL = "https://geocoding-api.open-meteo.com/v1/search"
    
    // MARK: - Fetch Weather
    
    /// Fetches weather for yesterday, today, and tomorrow
    /// - Parameters:
    ///   - city: The city to fetch weather for
    ///   - unit: The temperature unit (celsius or fahrenheit)
    /// - Returns: A tuple containing (yesterday, today, tomorrow) weather data
    func fetchWeather(for city: SavedCity, unit: TemperatureUnit = .celsius) async throws -> (yesterday: DayWeather, today: DayWeather, tomorrow: DayWeather) {
        
        // Calculate date range: yesterday through tomorrow
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let startDate = dateFormatter.string(from: yesterday)
        let endDate = dateFormatter.string(from: tomorrow)
        
        // Build the API URL with query parameters
        var components = URLComponents(string: weatherBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(city.latitude)),
            URLQueryItem(name: "longitude", value: String(city.longitude)),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,weathercode"),
            URLQueryItem(name: "hourly", value: "temperature_2m"),
            URLQueryItem(name: "current_weather", value: "true"),
            URLQueryItem(name: "temperature_unit", value: unit.apiValue),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate)
        ]
        
        guard let url = components.url else {
            throw WeatherError.invalidURL
        }
        
        // Make the network request
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Check for HTTP errors
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WeatherError.serverError
        }
        
        // Decode the JSON response
        let decoder = JSONDecoder()
        let weatherResponse = try decoder.decode(WeatherAPIResponse.self, from: data)
        
        // Parse hourly data for each day
        let hourlyByDay = parseHourlyData(weatherResponse.hourly, dates: [yesterday, today, tomorrow])
        
        // Convert API response to our app models
        let weatherDays = try parseWeatherResponse(weatherResponse, dates: [yesterday, today, tomorrow], hourlyByDay: hourlyByDay)
        
        guard weatherDays.count >= 3 else {
            throw WeatherError.insufficientData
        }
        
        // Add current temperature to today's weather
        var todayWeather = weatherDays[1]
        if let currentWeather = weatherResponse.currentWeather {
            todayWeather = DayWeather(
                date: todayWeather.date,
                highTemp: todayWeather.highTemp,
                lowTemp: todayWeather.lowTemp,
                currentTemp: Int(currentWeather.temperature.rounded()),
                condition: todayWeather.condition,
                hourlyTemps: todayWeather.hourlyTemps
            )
        }
        
        return (weatherDays[0], todayWeather, weatherDays[2])
    }
    
    // MARK: - Search Cities (for future city selection feature)
    
    /// Searches for cities matching the given query
    /// - Parameter query: The search string
    /// - Returns: Array of matching cities
    func searchCities(query: String) async throws -> [SavedCity] {
        guard !query.isEmpty else { return [] }
        
        var components = URLComponents(string: geocodingBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "10"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json")
        ]
        
        guard let url = components.url else {
            throw WeatherError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WeatherError.serverError
        }
        
        let decoder = JSONDecoder()
        let geocodingResponse = try decoder.decode(GeocodingResponse.self, from: data)
        
        return geocodingResponse.results?.map { $0.toSavedCity() } ?? []
    }
    
    // MARK: - Private Helpers
    
    /// Parses hourly data and groups it by day
    private func parseHourlyData(_ hourly: HourlyWeather?, dates: [Date]) -> [[HourlyTemp]] {
        guard let hourly = hourly else {
            return dates.map { _ in [] }
        }
        
        let calendar = Calendar.current
        var hourlyByDay: [[HourlyTemp]] = dates.map { _ in [] }
        
        // Parse the hourly time strings and temperatures
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        
        for (index, timeString) in hourly.time.enumerated() {
            guard index < hourly.temperature.count else { break }
            
            // Parse the ISO8601 time string (e.g., "2024-12-24T09:00")
            if let date = dateFormatter.date(from: timeString + ":00") ?? parseDateFallback(timeString) {
                let hour = calendar.component(.hour, from: date)
                let temp = hourly.temperature[index]
                
                // Find which day this hour belongs to
                for (dayIndex, dayDate) in dates.enumerated() {
                    if calendar.isDate(date, inSameDayAs: dayDate) {
                        hourlyByDay[dayIndex].append(HourlyTemp(hour: hour, temp: temp))
                        break
                    }
                }
            }
        }
        
        return hourlyByDay
    }
    
    /// Fallback date parser for hourly time strings
    private func parseDateFallback(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: timeString)
    }
    
    private func parseWeatherResponse(_ response: WeatherAPIResponse, dates: [Date], hourlyByDay: [[HourlyTemp]]) throws -> [DayWeather] {
        let daily = response.daily
        
        guard daily.time.count >= 3,
              daily.temperatureMax.count >= 3,
              daily.temperatureMin.count >= 3,
              daily.weathercode.count >= 3 else {
            throw WeatherError.insufficientData
        }
        
        return dates.enumerated().map { index, date in
            DayWeather(
                date: date,
                highTemp: Int(daily.temperatureMax[index].rounded()),
                lowTemp: Int(daily.temperatureMin[index].rounded()),
                currentTemp: nil,
                condition: mapWeatherCode(daily.weathercode[index]),
                hourlyTemps: index < hourlyByDay.count ? hourlyByDay[index] : []
            )
        }
    }
    
    /// Maps Open-Meteo weather codes to our WeatherCondition enum
    /// See: https://open-meteo.com/en/docs for weather code definitions
    private func mapWeatherCode(_ code: Int) -> WeatherCondition {
        switch code {
        case 0:
            return .sunny           // Clear sky
        case 1, 2:
            return .partlyCloudy    // Mainly clear, partly cloudy
        case 3:
            return .cloudy          // Overcast
        case 45, 48:
            return .foggy           // Fog
        case 51, 53, 55, 56, 57:
            return .rainy           // Drizzle
        case 61, 63, 65:
            return .rainy           // Rain
        case 66, 67:
            return .sleet           // Freezing rain
        case 71, 73, 75, 77:
            return .snowy           // Snow
        case 80, 81, 82:
            return .rainy           // Rain showers
        case 85, 86:
            return .snowy           // Snow showers
        case 95, 96, 99:
            return .stormy          // Thunderstorm
        default:
            return .cloudy
        }
    }
}

// MARK: - Error Types

enum WeatherError: LocalizedError {
    case invalidURL
    case serverError
    case decodingError
    case insufficientData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .serverError:
            return "Server error. Please try again."
        case .decodingError:
            return "Unable to read weather data"
        case .insufficientData:
            return "Not enough weather data available"
        }
    }
}
