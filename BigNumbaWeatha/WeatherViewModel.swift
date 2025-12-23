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
