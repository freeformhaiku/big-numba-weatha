import Foundation
import SwiftUI

/// ViewModel that manages weather data and app state
/// Uses @MainActor to ensure UI updates happen on the main thread
@MainActor
class WeatherViewModel: ObservableObject {
    
    // MARK: - Published Properties (UI will update when these change)
    
    @Published var yesterdayWeather: DayWeather?
    @Published var todayWeather: DayWeather?
    @Published var tomorrowWeather: DayWeather?
    
    @Published var currentCity: SavedCity
    @Published var savedCities: [SavedCity] = []
    
    @Published var temperatureUnit: TemperatureUnit = .celsius
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let weatherService = WeatherService.shared
    
    // UserDefaults keys for persistence
    private let savedCitiesKey = "savedCities"
    private let currentCityKey = "currentCity"
    private let temperatureUnitKey = "temperatureUnit"
    
    // MARK: - Preset Cities
    
    /// Major cities available for quick selection
    static let presetCities: [SavedCity] = [
        // North America
        SavedCity(name: "Toronto", region: "ON", country: "Canada", latitude: 43.6532, longitude: -79.3832),
        SavedCity(name: "New York", region: "NY", country: "United States", latitude: 40.7128, longitude: -74.0060),
        SavedCity(name: "Los Angeles", region: "CA", country: "United States", latitude: 34.0522, longitude: -118.2437),
        SavedCity(name: "Chicago", region: "IL", country: "United States", latitude: 41.8781, longitude: -87.6298),
        SavedCity(name: "Vancouver", region: "BC", country: "Canada", latitude: 49.2827, longitude: -123.1207),
        SavedCity(name: "Montreal", region: "QC", country: "Canada", latitude: 45.5017, longitude: -73.5673),
        SavedCity(name: "Mexico City", region: "CDMX", country: "Mexico", latitude: 19.4326, longitude: -99.1332),
        
        // Europe
        SavedCity(name: "London", region: "England", country: "United Kingdom", latitude: 51.5074, longitude: -0.1278),
        SavedCity(name: "Paris", region: "Île-de-France", country: "France", latitude: 48.8566, longitude: 2.3522),
        SavedCity(name: "Berlin", region: "Berlin", country: "Germany", latitude: 52.5200, longitude: 13.4050),
        SavedCity(name: "Madrid", region: "Madrid", country: "Spain", latitude: 40.4168, longitude: -3.7038),
        SavedCity(name: "Rome", region: "Lazio", country: "Italy", latitude: 41.9028, longitude: 12.4964),
        SavedCity(name: "Amsterdam", region: "North Holland", country: "Netherlands", latitude: 52.3676, longitude: 4.9041),
        SavedCity(name: "Warsaw", region: "Masovian", country: "Poland", latitude: 52.2297, longitude: 21.0122),
        SavedCity(name: "Vienna", region: "Vienna", country: "Austria", latitude: 48.2082, longitude: 16.3738),
        SavedCity(name: "Prague", region: "Prague", country: "Czech Republic", latitude: 50.0755, longitude: 14.4378),
        SavedCity(name: "Stockholm", region: "Stockholm", country: "Sweden", latitude: 59.3293, longitude: 18.0686),
        SavedCity(name: "Copenhagen", region: "Capital Region", country: "Denmark", latitude: 55.6761, longitude: 12.5683),
        SavedCity(name: "Dublin", region: "Leinster", country: "Ireland", latitude: 53.3498, longitude: -6.2603),
        SavedCity(name: "Lisbon", region: "Lisbon", country: "Portugal", latitude: 38.7223, longitude: -9.1393),
        SavedCity(name: "Brussels", region: "Brussels", country: "Belgium", latitude: 50.8503, longitude: 4.3517),
        SavedCity(name: "Zurich", region: "Zurich", country: "Switzerland", latitude: 47.3769, longitude: 8.5417),
        SavedCity(name: "Barcelona", region: "Catalonia", country: "Spain", latitude: 41.3851, longitude: 2.1734),
        SavedCity(name: "Munich", region: "Bavaria", country: "Germany", latitude: 48.1351, longitude: 11.5820),
        SavedCity(name: "Milan", region: "Lombardy", country: "Italy", latitude: 45.4642, longitude: 9.1900),
        SavedCity(name: "Athens", region: "Attica", country: "Greece", latitude: 37.9838, longitude: 23.7275),
        SavedCity(name: "Budapest", region: "Budapest", country: "Hungary", latitude: 47.4979, longitude: 19.0402),
        SavedCity(name: "Helsinki", region: "Uusimaa", country: "Finland", latitude: 60.1699, longitude: 24.9384),
        SavedCity(name: "Oslo", region: "Oslo", country: "Norway", latitude: 59.9139, longitude: 10.7522),
        
        // Asia & Pacific
        SavedCity(name: "Tokyo", region: "Tokyo", country: "Japan", latitude: 35.6762, longitude: 139.6503),
        SavedCity(name: "Sydney", region: "NSW", country: "Australia", latitude: -33.8688, longitude: 151.2093),
        SavedCity(name: "Singapore", region: "Singapore", country: "Singapore", latitude: 1.3521, longitude: 103.8198),
        SavedCity(name: "Hong Kong", region: "Hong Kong", country: "China", latitude: 22.3193, longitude: 114.1694),
        SavedCity(name: "Seoul", region: "Seoul", country: "South Korea", latitude: 37.5665, longitude: 126.9780),
        SavedCity(name: "Dubai", region: "Dubai", country: "UAE", latitude: 25.2048, longitude: 55.2708),
    ]
    
    // MARK: - Initialization
    
    init() {
        // Default to Toronto
        let defaultCity = SavedCity(
            name: "Toronto",
            region: "ON",
            country: "Canada",
            latitude: 43.6532,
            longitude: -79.3832
        )
        
        // Try to load saved current city, or use default
        if let savedCityData = UserDefaults.standard.data(forKey: currentCityKey),
           let savedCity = try? JSONDecoder().decode(SavedCity.self, from: savedCityData) {
            self.currentCity = savedCity
        } else {
            self.currentCity = defaultCity
        }
        
        // Load saved cities list
        loadSavedCities()
        
        // Load temperature unit preference
        loadTemperatureUnit()
    }
    
    // MARK: - Public Methods
    
    /// Fetches weather data for the current city
    func fetchWeather() async {
        // Prevent duplicate requests
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let weather = try await weatherService.fetchWeather(for: currentCity, unit: temperatureUnit)
            
            yesterdayWeather = weather.yesterday
            todayWeather = weather.today
            tomorrowWeather = weather.tomorrow
            
        } catch is CancellationError {
            // Ignore cancellation - this is normal when refreshing
            print("Weather fetch was cancelled")
        } catch let error as NSError where error.code == NSURLErrorCancelled {
            // Also ignore URL session cancellation
            print("URL request was cancelled")
        } catch {
            errorMessage = error.localizedDescription
            print("Weather fetch error: \(error)")
        }
        
        isLoading = false
    }
    
    /// Changes the temperature unit and refetches weather
    func setTemperatureUnit(_ unit: TemperatureUnit) async {
        // Don't update the displayed unit yet - wait for data to load
        guard !isLoading else { return }
        
        isLoading = true
        
        do {
            let weather = try await weatherService.fetchWeather(for: currentCity, unit: unit)
            
            // Update both the data AND the unit at the same time
            yesterdayWeather = weather.yesterday
            todayWeather = weather.today
            tomorrowWeather = weather.tomorrow
            temperatureUnit = unit
            saveTemperatureUnit()
            
        } catch is CancellationError {
            print("Weather fetch was cancelled")
        } catch let error as NSError where error.code == NSURLErrorCancelled {
            print("URL request was cancelled")
        } catch {
            print("Weather fetch error: \(error)")
            // Don't change the unit if the fetch failed
        }
        
        isLoading = false
    }
    
    /// Changes the current city and fetches new weather data
    func selectCity(_ city: SavedCity) async {
        currentCity = city
        saveCurrentCity()
        await fetchWeather()
    }
    
    /// Adds a city to the saved cities list
    func addCity(_ city: SavedCity) {
        // Don't add duplicates
        guard !savedCities.contains(where: { $0.name == city.name && $0.region == city.region }) else {
            return
        }
        savedCities.append(city)
        saveCitiesToStorage()
    }
    
    /// Removes a city from the saved cities list
    func removeCity(_ city: SavedCity) {
        savedCities.removeAll { $0.id == city.id }
        saveCitiesToStorage()
    }
    
    /// Searches for cities matching the query
    func searchCities(query: String) async -> [SavedCity] {
        do {
            return try await weatherService.searchCities(query: query)
        } catch {
            print("City search error: \(error)")
            return []
        }
    }
    
    // MARK: - Private Methods
    
    private func loadSavedCities() {
        if let data = UserDefaults.standard.data(forKey: savedCitiesKey),
           let cities = try? JSONDecoder().decode([SavedCity].self, from: data) {
            savedCities = cities
        }
    }
    
    private func saveCitiesToStorage() {
        if let data = try? JSONEncoder().encode(savedCities) {
            UserDefaults.standard.set(data, forKey: savedCitiesKey)
        }
    }
    
    private func saveCurrentCity() {
        if let data = try? JSONEncoder().encode(currentCity) {
            UserDefaults.standard.set(data, forKey: currentCityKey)
        }
    }
    
    private func loadTemperatureUnit() {
        if let savedUnit = UserDefaults.standard.string(forKey: temperatureUnitKey),
           let unit = TemperatureUnit(rawValue: savedUnit) {
            temperatureUnit = unit
        }
    }
    
    private func saveTemperatureUnit() {
        UserDefaults.standard.set(temperatureUnit.rawValue, forKey: temperatureUnitKey)
    }
}

// MARK: - Date Formatting Helpers

extension Date {
    
    /// Returns the full formatted date string: "Wednesday, December 24th"
    var fullDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        let dateString = formatter.string(from: self)
        
        // Add ordinal suffix (1st, 2nd, 3rd, etc.)
        let day = Calendar.current.component(.day, from: self)
        let suffix = daySuffix(for: day)
        
        return dateString + suffix
    }
    
    /// Returns the abbreviated date string: "Tue, Dec 23rd"
    var abbreviatedDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        let dateString = formatter.string(from: self)
        
        let day = Calendar.current.component(.day, from: self)
        let suffix = daySuffix(for: day)
        
        return dateString + suffix
    }
    
    /// Returns the ordinal suffix for a day number
    private func daySuffix(for day: Int) -> String {
        switch day {
        case 1, 21, 31:
            return "st"
        case 2, 22:
            return "nd"
        case 3, 23:
            return "rd"
        default:
            return "th"
        }
    }
}
