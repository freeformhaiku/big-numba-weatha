import Foundation
import SwiftUI

/// Full weather data for a city (yesterday, today, tomorrow)
struct CityFullWeather {
    let yesterday: DayWeather
    let today: DayWeather
    let tomorrow: DayWeather
}

/// ViewModel that manages weather data and app state
/// Uses @MainActor to ensure UI updates happen on the main thread
@MainActor
class WeatherViewModel: ObservableObject {
    
    // MARK: - Published Properties (UI will update when these change)
    
    @Published var yesterdayWeather: DayWeather?
    @Published var todayWeather: DayWeather?
    @Published var tomorrowWeather: DayWeather?
    
    // Per-city full weather data cache
    @Published var cityWeatherCache: [UUID: CityFullWeather] = [:]
    
    @Published var currentCity: SavedCity
    @Published var savedCities: [SavedCity] = []
    @Published var savedCityWeather: [String: CityWeatherSummary] = [:] // city.id -> weather summary
    
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
        SavedCity(name: "Washington D.C.", region: "DC", country: "United States", latitude: 38.9072, longitude: -77.0369),
        SavedCity(name: "San Francisco", region: "CA", country: "United States", latitude: 37.7749, longitude: -122.4194),
        SavedCity(name: "Seattle", region: "WA", country: "United States", latitude: 47.6062, longitude: -122.3321),
        SavedCity(name: "Miami", region: "FL", country: "United States", latitude: 25.7617, longitude: -80.1918),
        SavedCity(name: "Boston", region: "MA", country: "United States", latitude: 42.3601, longitude: -71.0589),
        SavedCity(name: "Atlanta", region: "GA", country: "United States", latitude: 33.7490, longitude: -84.3880),
        SavedCity(name: "Denver", region: "CO", country: "United States", latitude: 39.7392, longitude: -104.9903),
        SavedCity(name: "Austin", region: "TX", country: "United States", latitude: 30.2672, longitude: -97.7431),
        SavedCity(name: "Dallas", region: "TX", country: "United States", latitude: 32.7767, longitude: -96.7970),
        SavedCity(name: "Houston", region: "TX", country: "United States", latitude: 29.7604, longitude: -95.3698),
        SavedCity(name: "Phoenix", region: "AZ", country: "United States", latitude: 33.4484, longitude: -112.0740),
        SavedCity(name: "Philadelphia", region: "PA", country: "United States", latitude: 39.9526, longitude: -75.1652),
        SavedCity(name: "San Diego", region: "CA", country: "United States", latitude: 32.7157, longitude: -117.1611),
        SavedCity(name: "Calgary", region: "AB", country: "Canada", latitude: 51.0447, longitude: -114.0719),
        SavedCity(name: "Ottawa", region: "ON", country: "Canada", latitude: 45.4215, longitude: -75.6972),
        SavedCity(name: "Edmonton", region: "AB", country: "Canada", latitude: 53.5461, longitude: -113.4938),
        SavedCity(name: "Winnipeg", region: "MB", country: "Canada", latitude: 49.8951, longitude: -97.1384),
        SavedCity(name: "Halifax", region: "NS", country: "Canada", latitude: 44.6488, longitude: -63.5752),
        
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
        SavedCity(name: "Melbourne", region: "VIC", country: "Australia", latitude: -37.8136, longitude: 144.9631),
        SavedCity(name: "Bangkok", region: "Bangkok", country: "Thailand", latitude: 13.7563, longitude: 100.5018),
        SavedCity(name: "Mumbai", region: "Maharashtra", country: "India", latitude: 19.0760, longitude: 72.8777),
        SavedCity(name: "Delhi", region: "Delhi", country: "India", latitude: 28.6139, longitude: 77.2090),
        SavedCity(name: "Shanghai", region: "Shanghai", country: "China", latitude: 31.2304, longitude: 121.4737),
        SavedCity(name: "Beijing", region: "Beijing", country: "China", latitude: 39.9042, longitude: 116.4074),
        SavedCity(name: "Taipei", region: "Taiwan", country: "Taiwan", latitude: 25.0330, longitude: 121.5654),
        SavedCity(name: "Manila", region: "Metro Manila", country: "Philippines", latitude: 14.5995, longitude: 120.9842),
        SavedCity(name: "Jakarta", region: "Jakarta", country: "Indonesia", latitude: -6.2088, longitude: 106.8456),
        SavedCity(name: "Kuala Lumpur", region: "KL", country: "Malaysia", latitude: 3.1390, longitude: 101.6869),
        SavedCity(name: "Auckland", region: "Auckland", country: "New Zealand", latitude: -36.8485, longitude: 174.7633),
        SavedCity(name: "Osaka", region: "Osaka", country: "Japan", latitude: 34.6937, longitude: 135.5023),
        
        // South America
        SavedCity(name: "São Paulo", region: "SP", country: "Brazil", latitude: -23.5505, longitude: -46.6333),
        SavedCity(name: "Rio de Janeiro", region: "RJ", country: "Brazil", latitude: -22.9068, longitude: -43.1729),
        SavedCity(name: "Buenos Aires", region: "BA", country: "Argentina", latitude: -34.6037, longitude: -58.3816),
        SavedCity(name: "Lima", region: "Lima", country: "Peru", latitude: -12.0464, longitude: -77.0428),
        SavedCity(name: "Bogotá", region: "Bogotá", country: "Colombia", latitude: 4.7110, longitude: -74.0721),
        SavedCity(name: "Santiago", region: "Santiago", country: "Chile", latitude: -33.4489, longitude: -70.6693),
        
        // Africa & Middle East
        SavedCity(name: "Cairo", region: "Cairo", country: "Egypt", latitude: 30.0444, longitude: 31.2357),
        SavedCity(name: "Cape Town", region: "Western Cape", country: "South Africa", latitude: -33.9249, longitude: 18.4241),
        SavedCity(name: "Lagos", region: "Lagos", country: "Nigeria", latitude: 6.5244, longitude: 3.3792),
        SavedCity(name: "Nairobi", region: "Nairobi", country: "Kenya", latitude: -1.2921, longitude: 36.8219),
        SavedCity(name: "Tel Aviv", region: "Tel Aviv", country: "Israel", latitude: 32.0853, longitude: 34.7818),
        SavedCity(name: "Johannesburg", region: "Gauteng", country: "South Africa", latitude: -26.2041, longitude: 28.0473),
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
            
            // Cache this city's full weather data
            cityWeatherCache[currentCity.id] = CityFullWeather(
                yesterday: weather.yesterday,
                today: weather.today,
                tomorrow: weather.tomorrow
            )
            
            // Also fetch weather for saved cities
            await fetchSavedCitiesWeather()
            
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
    
    /// Gets cached weather for a city, or nil if not cached
    func getCachedWeather(for city: SavedCity) -> CityFullWeather? {
        return cityWeatherCache[city.id]
    }
    
    /// Changes the temperature unit and refetches weather
    func setTemperatureUnit(_ unit: TemperatureUnit) async {
        // Don't update the displayed unit yet - wait for data to load
        guard !isLoading else { return }
        
        isLoading = true
        
        // Clear all cached weather since unit is changing
        cityWeatherCache.removeAll()
        
        do {
            let weather = try await weatherService.fetchWeather(for: currentCity, unit: unit)
            
            // Update both the data AND the unit at the same time
            yesterdayWeather = weather.yesterday
            todayWeather = weather.today
            tomorrowWeather = weather.tomorrow
            temperatureUnit = unit
            saveTemperatureUnit()
            
            // Cache this city's data
            cityWeatherCache[currentCity.id] = CityFullWeather(
                yesterday: weather.yesterday,
                today: weather.today,
                tomorrow: weather.tomorrow
            )
            
            // Refetch all saved cities with new unit
            await fetchSavedCitiesWeather()
            
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
        // Fetch weather if not already cached
        if cityWeatherCache[city.id] == nil {
            await fetchFullWeatherForCity(city, forceRefresh: false)
        }
        // Update the main weather properties for backward compatibility
        if let cached = cityWeatherCache[city.id] {
            yesterdayWeather = cached.yesterday
            todayWeather = cached.today
            tomorrowWeather = cached.tomorrow
        }
    }
    
    /// Adds a city to the saved cities list and fetches its weather
    func addCity(_ city: SavedCity) async {
        // Don't add duplicates
        guard !savedCities.contains(where: { $0.name == city.name && $0.region == city.region }) else {
            return
        }
        savedCities.append(city)
        saveCitiesToStorage()
        
        // Fetch weather for the new city
        await fetchWeatherForCity(city)
    }
    
    /// Adds a city to My Cities and switches to it
    func addCityAndSelect(_ city: SavedCity) async {
        // Add to saved cities if not already there
        if !savedCities.contains(where: { $0.name == city.name && $0.region == city.region }) {
            savedCities.append(city)
            saveCitiesToStorage()
        }
        
        // Switch to the new city
        currentCity = city
        saveCurrentCity()
        await fetchWeather()
        
        // Fetch weather for all saved cities
        await fetchSavedCitiesWeather()
    }
    
    /// Fetches weather summary for a single saved city
    private func fetchWeatherForCity(_ city: SavedCity) async {
        do {
            let summary = try await weatherService.fetchWeatherSummary(for: city, unit: temperatureUnit)
            savedCityWeather[city.id.uuidString] = summary
        } catch {
            print("Failed to fetch weather for \(city.name): \(error)")
        }
    }
    
    /// Fetches weather for all saved cities
    func fetchSavedCitiesWeather() async {
        for city in savedCities {
            await fetchWeatherForCity(city)
        }
    }

    /// Fetches full weather data for ALL saved cities (including hourly data)
    /// Called on app open to ensure fresh data for all cities
    func fetchAllCitiesFullWeather() async {
        // Collect all cities to fetch (current + saved, avoiding duplicates)
        var citiesToFetch = savedCities
        if !citiesToFetch.contains(where: { $0.id == currentCity.id }) {
            citiesToFetch.append(currentCity)
        }

        await withTaskGroup(of: Void.self) { group in
            for city in citiesToFetch {
                group.addTask {
                    await self.fetchFullWeatherForCity(city, forceRefresh: true)
                }
            }
        }
    }

    /// Fetches full weather data for a specific city (used by city pages)
    /// - Parameters:
    ///   - city: The city to fetch weather for
    ///   - forceRefresh: If true, ignores cache and fetches fresh data
    func fetchFullWeatherForCity(_ city: SavedCity, forceRefresh: Bool) async {
        // Check if we already have cached data (unless forcing refresh)
        if !forceRefresh && cityWeatherCache[city.id] != nil {
            return
        }

        do {
            let weather = try await weatherService.fetchWeather(for: city, unit: temperatureUnit)
            cityWeatherCache[city.id] = CityFullWeather(
                yesterday: weather.yesterday,
                today: weather.today,
                tomorrow: weather.tomorrow
            )
        } catch {
            print("Failed to fetch weather for \(city.name): \(error)")
        }
    }
    
    /// Removes a city from the saved cities list
    func removeCity(_ city: SavedCity) {
        savedCities.removeAll { $0.id == city.id }
        savedCityWeather.removeValue(forKey: city.id.uuidString)
        saveCitiesToStorage()
    }
    
    /// Moves a city from one position to another (for reordering)
    func moveCity(from source: Int, to destination: Int) {
        guard source != destination,
              source >= 0, source < savedCities.count,
              destination >= 0, destination < savedCities.count else {
            return
        }
        
        let city = savedCities.remove(at: source)
        savedCities.insert(city, at: destination)
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
