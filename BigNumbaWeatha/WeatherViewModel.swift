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
        // North America - United States
        SavedCity(name: "New York", region: "NY", country: "United States", latitude: 40.7128, longitude: -74.0060),
        SavedCity(name: "Los Angeles", region: "CA", country: "United States", latitude: 34.0522, longitude: -118.2437),
        SavedCity(name: "Chicago", region: "IL", country: "United States", latitude: 41.8781, longitude: -87.6298),
        SavedCity(name: "Houston", region: "TX", country: "United States", latitude: 29.7604, longitude: -95.3698),
        SavedCity(name: "Phoenix", region: "AZ", country: "United States", latitude: 33.4484, longitude: -112.0740),
        SavedCity(name: "Philadelphia", region: "PA", country: "United States", latitude: 39.9526, longitude: -75.1652),
        SavedCity(name: "San Antonio", region: "TX", country: "United States", latitude: 29.4241, longitude: -98.4936),
        SavedCity(name: "San Diego", region: "CA", country: "United States", latitude: 32.7157, longitude: -117.1611),
        SavedCity(name: "Dallas", region: "TX", country: "United States", latitude: 32.7767, longitude: -96.7970),
        SavedCity(name: "San Jose", region: "CA", country: "United States", latitude: 37.3382, longitude: -121.8863),
        SavedCity(name: "Austin", region: "TX", country: "United States", latitude: 30.2672, longitude: -97.7431),
        SavedCity(name: "Jacksonville", region: "FL", country: "United States", latitude: 30.3322, longitude: -81.6557),
        SavedCity(name: "Fort Worth", region: "TX", country: "United States", latitude: 32.7555, longitude: -97.3308),
        SavedCity(name: "Columbus", region: "OH", country: "United States", latitude: 39.9612, longitude: -82.9988),
        SavedCity(name: "Charlotte", region: "NC", country: "United States", latitude: 35.2271, longitude: -80.8431),
        SavedCity(name: "San Francisco", region: "CA", country: "United States", latitude: 37.7749, longitude: -122.4194),
        SavedCity(name: "Indianapolis", region: "IN", country: "United States", latitude: 39.7684, longitude: -86.1581),
        SavedCity(name: "Seattle", region: "WA", country: "United States", latitude: 47.6062, longitude: -122.3321),
        SavedCity(name: "Denver", region: "CO", country: "United States", latitude: 39.7392, longitude: -104.9903),
        SavedCity(name: "Washington D.C.", region: "DC", country: "United States", latitude: 38.9072, longitude: -77.0369),
        SavedCity(name: "Boston", region: "MA", country: "United States", latitude: 42.3601, longitude: -71.0589),
        SavedCity(name: "Nashville", region: "TN", country: "United States", latitude: 36.1627, longitude: -86.7816),
        SavedCity(name: "Detroit", region: "MI", country: "United States", latitude: 42.3314, longitude: -83.0458),
        SavedCity(name: "Portland", region: "OR", country: "United States", latitude: 45.5152, longitude: -122.6784),
        SavedCity(name: "Las Vegas", region: "NV", country: "United States", latitude: 36.1699, longitude: -115.1398),
        SavedCity(name: "Memphis", region: "TN", country: "United States", latitude: 35.1495, longitude: -90.0490),
        SavedCity(name: "Louisville", region: "KY", country: "United States", latitude: 38.2527, longitude: -85.7585),
        SavedCity(name: "Baltimore", region: "MD", country: "United States", latitude: 39.2904, longitude: -76.6122),
        SavedCity(name: "Milwaukee", region: "WI", country: "United States", latitude: 43.0389, longitude: -87.9065),
        SavedCity(name: "Albuquerque", region: "NM", country: "United States", latitude: 35.0844, longitude: -106.6504),
        SavedCity(name: "Tucson", region: "AZ", country: "United States", latitude: 32.2226, longitude: -110.9747),
        SavedCity(name: "Fresno", region: "CA", country: "United States", latitude: 36.7378, longitude: -119.7871),
        SavedCity(name: "Sacramento", region: "CA", country: "United States", latitude: 38.5816, longitude: -121.4944),
        SavedCity(name: "Atlanta", region: "GA", country: "United States", latitude: 33.7490, longitude: -84.3880),
        SavedCity(name: "Miami", region: "FL", country: "United States", latitude: 25.7617, longitude: -80.1918),
        SavedCity(name: "New Orleans", region: "LA", country: "United States", latitude: 29.9511, longitude: -90.0715),
        SavedCity(name: "Honolulu", region: "HI", country: "United States", latitude: 21.3069, longitude: -157.8583),
        SavedCity(name: "Minneapolis", region: "MN", country: "United States", latitude: 44.9778, longitude: -93.2650),
        SavedCity(name: "Cleveland", region: "OH", country: "United States", latitude: 41.4993, longitude: -81.6944),
        SavedCity(name: "Orlando", region: "FL", country: "United States", latitude: 28.5383, longitude: -81.3792),
        SavedCity(name: "Tampa", region: "FL", country: "United States", latitude: 27.9506, longitude: -82.4572),
        SavedCity(name: "Pittsburgh", region: "PA", country: "United States", latitude: 40.4406, longitude: -79.9959),
        SavedCity(name: "Cincinnati", region: "OH", country: "United States", latitude: 39.1031, longitude: -84.5120),
        SavedCity(name: "Raleigh", region: "NC", country: "United States", latitude: 35.7796, longitude: -78.6382),
        SavedCity(name: "Salt Lake City", region: "UT", country: "United States", latitude: 40.7608, longitude: -111.8910),
        SavedCity(name: "Kansas City", region: "MO", country: "United States", latitude: 39.0997, longitude: -94.5786),
        SavedCity(name: "St. Louis", region: "MO", country: "United States", latitude: 38.6270, longitude: -90.1994),
        SavedCity(name: "San Bernardino", region: "CA", country: "United States", latitude: 34.1083, longitude: -117.2898),
        SavedCity(name: "La Quinta", region: "CA", country: "United States", latitude: 33.6634, longitude: -116.3100),
        SavedCity(name: "Palm Springs", region: "CA", country: "United States", latitude: 33.8303, longitude: -116.5453),
        SavedCity(name: "Santa Barbara", region: "CA", country: "United States", latitude: 34.4208, longitude: -119.6982),
        SavedCity(name: "Santa Monica", region: "CA", country: "United States", latitude: 34.0195, longitude: -118.4912),
        SavedCity(name: "Pasadena", region: "CA", country: "United States", latitude: 34.1478, longitude: -118.1445),
        SavedCity(name: "Anaheim", region: "CA", country: "United States", latitude: 33.8366, longitude: -117.9143),
        SavedCity(name: "Irvine", region: "CA", country: "United States", latitude: 33.6846, longitude: -117.8265),
        SavedCity(name: "Oakland", region: "CA", country: "United States", latitude: 37.8044, longitude: -122.2712),
        SavedCity(name: "Berkeley", region: "CA", country: "United States", latitude: 37.8716, longitude: -122.2727),
        SavedCity(name: "Palo Alto", region: "CA", country: "United States", latitude: 37.4419, longitude: -122.1430),
        SavedCity(name: "Santa Cruz", region: "CA", country: "United States", latitude: 36.9741, longitude: -122.0308),
        SavedCity(name: "Monterey", region: "CA", country: "United States", latitude: 36.6002, longitude: -121.8947),
        SavedCity(name: "Napa", region: "CA", country: "United States", latitude: 38.2975, longitude: -122.2869),
        SavedCity(name: "Anchorage", region: "AK", country: "United States", latitude: 61.2181, longitude: -149.9003),
        SavedCity(name: "Savannah", region: "GA", country: "United States", latitude: 32.0809, longitude: -81.0912),
        SavedCity(name: "Charleston", region: "SC", country: "United States", latitude: 32.7765, longitude: -79.9311),
        SavedCity(name: "Providence", region: "RI", country: "United States", latitude: 41.8240, longitude: -71.4128),
        SavedCity(name: "Hartford", region: "CT", country: "United States", latitude: 41.7658, longitude: -72.6734),
        SavedCity(name: "Buffalo", region: "NY", country: "United States", latitude: 42.8864, longitude: -78.8784),
        SavedCity(name: "Rochester", region: "NY", country: "United States", latitude: 43.1566, longitude: -77.6088),

        // North America - Canada
        SavedCity(name: "Toronto", region: "ON", country: "Canada", latitude: 43.6532, longitude: -79.3832),
        SavedCity(name: "Montreal", region: "QC", country: "Canada", latitude: 45.5017, longitude: -73.5673),
        SavedCity(name: "Vancouver", region: "BC", country: "Canada", latitude: 49.2827, longitude: -123.1207),
        SavedCity(name: "Calgary", region: "AB", country: "Canada", latitude: 51.0447, longitude: -114.0719),
        SavedCity(name: "Edmonton", region: "AB", country: "Canada", latitude: 53.5461, longitude: -113.4938),
        SavedCity(name: "Ottawa", region: "ON", country: "Canada", latitude: 45.4215, longitude: -75.6972),
        SavedCity(name: "Winnipeg", region: "MB", country: "Canada", latitude: 49.8951, longitude: -97.1384),
        SavedCity(name: "Quebec City", region: "QC", country: "Canada", latitude: 46.8139, longitude: -71.2080),
        SavedCity(name: "Hamilton", region: "ON", country: "Canada", latitude: 43.2557, longitude: -79.8711),
        SavedCity(name: "Kitchener", region: "ON", country: "Canada", latitude: 43.4516, longitude: -80.4925),
        SavedCity(name: "London", region: "ON", country: "Canada", latitude: 42.9849, longitude: -81.2453),
        SavedCity(name: "Victoria", region: "BC", country: "Canada", latitude: 48.4284, longitude: -123.3656),
        SavedCity(name: "Halifax", region: "NS", country: "Canada", latitude: 44.6488, longitude: -63.5752),
        SavedCity(name: "Saskatoon", region: "SK", country: "Canada", latitude: 52.1579, longitude: -106.6702),
        SavedCity(name: "Regina", region: "SK", country: "Canada", latitude: 50.4452, longitude: -104.6189),
        SavedCity(name: "St. John's", region: "NL", country: "Canada", latitude: 47.5615, longitude: -52.7126),
        SavedCity(name: "Kelowna", region: "BC", country: "Canada", latitude: 49.8880, longitude: -119.4960),
        SavedCity(name: "Whistler", region: "BC", country: "Canada", latitude: 50.1163, longitude: -122.9574),
        SavedCity(name: "Banff", region: "AB", country: "Canada", latitude: 51.1784, longitude: -115.5708),

        // North America - Mexico & Central America
        SavedCity(name: "Mexico City", region: "CDMX", country: "Mexico", latitude: 19.4326, longitude: -99.1332),
        SavedCity(name: "Guadalajara", region: "Jalisco", country: "Mexico", latitude: 20.6597, longitude: -103.3496),
        SavedCity(name: "Monterrey", region: "Nuevo León", country: "Mexico", latitude: 25.6866, longitude: -100.3161),
        SavedCity(name: "Cancún", region: "Quintana Roo", country: "Mexico", latitude: 21.1619, longitude: -86.8515),
        SavedCity(name: "Tijuana", region: "Baja California", country: "Mexico", latitude: 32.5149, longitude: -117.0382),
        SavedCity(name: "Puerto Vallarta", region: "Jalisco", country: "Mexico", latitude: 20.6534, longitude: -105.2253),
        SavedCity(name: "Playa del Carmen", region: "Quintana Roo", country: "Mexico", latitude: 20.6296, longitude: -87.0739),
        SavedCity(name: "Cabo San Lucas", region: "Baja California Sur", country: "Mexico", latitude: 22.8905, longitude: -109.9167),
        SavedCity(name: "Oaxaca", region: "Oaxaca", country: "Mexico", latitude: 17.0732, longitude: -96.7266),
        SavedCity(name: "Mérida", region: "Yucatán", country: "Mexico", latitude: 20.9674, longitude: -89.5926),
        SavedCity(name: "San Miguel de Allende", region: "Guanajuato", country: "Mexico", latitude: 20.9144, longitude: -100.7452),
        SavedCity(name: "Guatemala City", region: "Guatemala", country: "Guatemala", latitude: 14.6349, longitude: -90.5069),
        SavedCity(name: "San José", region: "San José", country: "Costa Rica", latitude: 9.9281, longitude: -84.0907),
        SavedCity(name: "Panama City", region: "Panamá", country: "Panama", latitude: 8.9824, longitude: -79.5199),
        SavedCity(name: "Havana", region: "Havana", country: "Cuba", latitude: 23.1136, longitude: -82.3666),
        SavedCity(name: "San Juan", region: "PR", country: "Puerto Rico", latitude: 18.4655, longitude: -66.1057),
        SavedCity(name: "Nassau", region: "New Providence", country: "Bahamas", latitude: 25.0480, longitude: -77.3554),
        SavedCity(name: "Kingston", region: "Kingston", country: "Jamaica", latitude: 17.9714, longitude: -76.7936),

        // Europe - Western
        SavedCity(name: "London", region: "England", country: "United Kingdom", latitude: 51.5074, longitude: -0.1278),
        SavedCity(name: "Manchester", region: "England", country: "United Kingdom", latitude: 53.4808, longitude: -2.2426),
        SavedCity(name: "Birmingham", region: "England", country: "United Kingdom", latitude: 52.4862, longitude: -1.8904),
        SavedCity(name: "Edinburgh", region: "Scotland", country: "United Kingdom", latitude: 55.9533, longitude: -3.1883),
        SavedCity(name: "Glasgow", region: "Scotland", country: "United Kingdom", latitude: 55.8642, longitude: -4.2518),
        SavedCity(name: "Liverpool", region: "England", country: "United Kingdom", latitude: 53.4084, longitude: -2.9916),
        SavedCity(name: "Bristol", region: "England", country: "United Kingdom", latitude: 51.4545, longitude: -2.5879),
        SavedCity(name: "Oxford", region: "England", country: "United Kingdom", latitude: 51.7520, longitude: -1.2577),
        SavedCity(name: "Cambridge", region: "England", country: "United Kingdom", latitude: 52.2053, longitude: 0.1218),
        SavedCity(name: "Paris", region: "Île-de-France", country: "France", latitude: 48.8566, longitude: 2.3522),
        SavedCity(name: "Lyon", region: "Auvergne-Rhône-Alpes", country: "France", latitude: 45.7640, longitude: 4.8357),
        SavedCity(name: "Marseille", region: "Provence-Alpes-Côte d'Azur", country: "France", latitude: 43.2965, longitude: 5.3698),
        SavedCity(name: "Nice", region: "Provence-Alpes-Côte d'Azur", country: "France", latitude: 43.7102, longitude: 7.2620),
        SavedCity(name: "Bordeaux", region: "Nouvelle-Aquitaine", country: "France", latitude: 44.8378, longitude: -0.5792),
        SavedCity(name: "Toulouse", region: "Occitanie", country: "France", latitude: 43.6047, longitude: 1.4442),
        SavedCity(name: "Strasbourg", region: "Grand Est", country: "France", latitude: 48.5734, longitude: 7.7521),
        SavedCity(name: "Amsterdam", region: "North Holland", country: "Netherlands", latitude: 52.3676, longitude: 4.9041),
        SavedCity(name: "Rotterdam", region: "South Holland", country: "Netherlands", latitude: 51.9225, longitude: 4.4792),
        SavedCity(name: "The Hague", region: "South Holland", country: "Netherlands", latitude: 52.0705, longitude: 4.3007),
        SavedCity(name: "Brussels", region: "Brussels", country: "Belgium", latitude: 50.8503, longitude: 4.3517),
        SavedCity(name: "Antwerp", region: "Flanders", country: "Belgium", latitude: 51.2194, longitude: 4.4025),
        SavedCity(name: "Dublin", region: "Leinster", country: "Ireland", latitude: 53.3498, longitude: -6.2603),
        SavedCity(name: "Cork", region: "Munster", country: "Ireland", latitude: 51.8985, longitude: -8.4756),
        SavedCity(name: "Galway", region: "Connacht", country: "Ireland", latitude: 53.2707, longitude: -9.0568),

        // Europe - Central
        SavedCity(name: "Berlin", region: "Berlin", country: "Germany", latitude: 52.5200, longitude: 13.4050),
        SavedCity(name: "Munich", region: "Bavaria", country: "Germany", latitude: 48.1351, longitude: 11.5820),
        SavedCity(name: "Frankfurt", region: "Hesse", country: "Germany", latitude: 50.1109, longitude: 8.6821),
        SavedCity(name: "Hamburg", region: "Hamburg", country: "Germany", latitude: 53.5511, longitude: 9.9937),
        SavedCity(name: "Cologne", region: "North Rhine-Westphalia", country: "Germany", latitude: 50.9375, longitude: 6.9603),
        SavedCity(name: "Düsseldorf", region: "North Rhine-Westphalia", country: "Germany", latitude: 51.2277, longitude: 6.7735),
        SavedCity(name: "Stuttgart", region: "Baden-Württemberg", country: "Germany", latitude: 48.7758, longitude: 9.1829),
        SavedCity(name: "Vienna", region: "Vienna", country: "Austria", latitude: 48.2082, longitude: 16.3738),
        SavedCity(name: "Salzburg", region: "Salzburg", country: "Austria", latitude: 47.8095, longitude: 13.0550),
        SavedCity(name: "Innsbruck", region: "Tyrol", country: "Austria", latitude: 47.2692, longitude: 11.4041),
        SavedCity(name: "Zurich", region: "Zurich", country: "Switzerland", latitude: 47.3769, longitude: 8.5417),
        SavedCity(name: "Geneva", region: "Geneva", country: "Switzerland", latitude: 46.2044, longitude: 6.1432),
        SavedCity(name: "Bern", region: "Bern", country: "Switzerland", latitude: 46.9480, longitude: 7.4474),
        SavedCity(name: "Basel", region: "Basel-Stadt", country: "Switzerland", latitude: 47.5596, longitude: 7.5886),
        SavedCity(name: "Prague", region: "Prague", country: "Czech Republic", latitude: 50.0755, longitude: 14.4378),
        SavedCity(name: "Warsaw", region: "Masovian", country: "Poland", latitude: 52.2297, longitude: 21.0122),
        SavedCity(name: "Kraków", region: "Lesser Poland", country: "Poland", latitude: 50.0647, longitude: 19.9450),
        SavedCity(name: "Gdańsk", region: "Pomeranian", country: "Poland", latitude: 54.3520, longitude: 18.6466),
        SavedCity(name: "Wrocław", region: "Lower Silesian", country: "Poland", latitude: 51.1079, longitude: 17.0385),
        SavedCity(name: "Budapest", region: "Budapest", country: "Hungary", latitude: 47.4979, longitude: 19.0402),

        // Europe - Southern
        SavedCity(name: "Rome", region: "Lazio", country: "Italy", latitude: 41.9028, longitude: 12.4964),
        SavedCity(name: "Milan", region: "Lombardy", country: "Italy", latitude: 45.4642, longitude: 9.1900),
        SavedCity(name: "Florence", region: "Tuscany", country: "Italy", latitude: 43.7696, longitude: 11.2558),
        SavedCity(name: "Venice", region: "Veneto", country: "Italy", latitude: 45.4408, longitude: 12.3155),
        SavedCity(name: "Naples", region: "Campania", country: "Italy", latitude: 40.8518, longitude: 14.2681),
        SavedCity(name: "Turin", region: "Piedmont", country: "Italy", latitude: 45.0703, longitude: 7.6869),
        SavedCity(name: "Bologna", region: "Emilia-Romagna", country: "Italy", latitude: 44.4949, longitude: 11.3426),
        SavedCity(name: "Palermo", region: "Sicily", country: "Italy", latitude: 38.1157, longitude: 13.3615),
        SavedCity(name: "Madrid", region: "Madrid", country: "Spain", latitude: 40.4168, longitude: -3.7038),
        SavedCity(name: "Barcelona", region: "Catalonia", country: "Spain", latitude: 41.3851, longitude: 2.1734),
        SavedCity(name: "Valencia", region: "Valencia", country: "Spain", latitude: 39.4699, longitude: -0.3763),
        SavedCity(name: "Seville", region: "Andalusia", country: "Spain", latitude: 37.3891, longitude: -5.9845),
        SavedCity(name: "Málaga", region: "Andalusia", country: "Spain", latitude: 36.7213, longitude: -4.4214),
        SavedCity(name: "Bilbao", region: "Basque Country", country: "Spain", latitude: 43.2630, longitude: -2.9350),
        SavedCity(name: "Granada", region: "Andalusia", country: "Spain", latitude: 37.1773, longitude: -3.5986),
        SavedCity(name: "Ibiza", region: "Balearic Islands", country: "Spain", latitude: 38.9067, longitude: 1.4206),
        SavedCity(name: "Palma de Mallorca", region: "Balearic Islands", country: "Spain", latitude: 39.5696, longitude: 2.6502),
        SavedCity(name: "Lisbon", region: "Lisbon", country: "Portugal", latitude: 38.7223, longitude: -9.1393),
        SavedCity(name: "Porto", region: "Porto", country: "Portugal", latitude: 41.1579, longitude: -8.6291),
        SavedCity(name: "Faro", region: "Algarve", country: "Portugal", latitude: 37.0194, longitude: -7.9322),
        SavedCity(name: "Athens", region: "Attica", country: "Greece", latitude: 37.9838, longitude: 23.7275),
        SavedCity(name: "Thessaloniki", region: "Central Macedonia", country: "Greece", latitude: 40.6401, longitude: 22.9444),
        SavedCity(name: "Santorini", region: "South Aegean", country: "Greece", latitude: 36.3932, longitude: 25.4615),
        SavedCity(name: "Mykonos", region: "South Aegean", country: "Greece", latitude: 37.4467, longitude: 25.3289),

        // Europe - Nordic
        SavedCity(name: "Stockholm", region: "Stockholm", country: "Sweden", latitude: 59.3293, longitude: 18.0686),
        SavedCity(name: "Gothenburg", region: "Västra Götaland", country: "Sweden", latitude: 57.7089, longitude: 11.9746),
        SavedCity(name: "Malmö", region: "Skåne", country: "Sweden", latitude: 55.6050, longitude: 13.0038),
        SavedCity(name: "Copenhagen", region: "Capital Region", country: "Denmark", latitude: 55.6761, longitude: 12.5683),
        SavedCity(name: "Oslo", region: "Oslo", country: "Norway", latitude: 59.9139, longitude: 10.7522),
        SavedCity(name: "Bergen", region: "Vestland", country: "Norway", latitude: 60.3913, longitude: 5.3221),
        SavedCity(name: "Tromsø", region: "Troms og Finnmark", country: "Norway", latitude: 69.6492, longitude: 18.9553),
        SavedCity(name: "Helsinki", region: "Uusimaa", country: "Finland", latitude: 60.1699, longitude: 24.9384),
        SavedCity(name: "Reykjavik", region: "Capital Region", country: "Iceland", latitude: 64.1466, longitude: -21.9426),

        // Europe - Eastern
        SavedCity(name: "Moscow", region: "Moscow", country: "Russia", latitude: 55.7558, longitude: 37.6173),
        SavedCity(name: "St. Petersburg", region: "Northwestern", country: "Russia", latitude: 59.9311, longitude: 30.3609),
        SavedCity(name: "Kyiv", region: "Kyiv", country: "Ukraine", latitude: 50.4501, longitude: 30.5234),
        SavedCity(name: "Bucharest", region: "Bucharest", country: "Romania", latitude: 44.4268, longitude: 26.1025),
        SavedCity(name: "Sofia", region: "Sofia", country: "Bulgaria", latitude: 42.6977, longitude: 23.3219),
        SavedCity(name: "Belgrade", region: "Belgrade", country: "Serbia", latitude: 44.7866, longitude: 20.4489),
        SavedCity(name: "Zagreb", region: "Zagreb", country: "Croatia", latitude: 45.8150, longitude: 15.9819),
        SavedCity(name: "Dubrovnik", region: "Dubrovnik-Neretva", country: "Croatia", latitude: 42.6507, longitude: 18.0944),
        SavedCity(name: "Split", region: "Split-Dalmatia", country: "Croatia", latitude: 43.5081, longitude: 16.4402),
        SavedCity(name: "Ljubljana", region: "Central Slovenia", country: "Slovenia", latitude: 46.0569, longitude: 14.5058),
        SavedCity(name: "Bratislava", region: "Bratislava", country: "Slovakia", latitude: 48.1486, longitude: 17.1077),
        SavedCity(name: "Tallinn", region: "Harju", country: "Estonia", latitude: 59.4370, longitude: 24.7536),
        SavedCity(name: "Riga", region: "Riga", country: "Latvia", latitude: 56.9496, longitude: 24.1052),
        SavedCity(name: "Vilnius", region: "Vilnius", country: "Lithuania", latitude: 54.6872, longitude: 25.2797),

        // Asia - East
        SavedCity(name: "Tokyo", region: "Tokyo", country: "Japan", latitude: 35.6762, longitude: 139.6503),
        SavedCity(name: "Osaka", region: "Osaka", country: "Japan", latitude: 34.6937, longitude: 135.5023),
        SavedCity(name: "Kyoto", region: "Kyoto", country: "Japan", latitude: 35.0116, longitude: 135.7681),
        SavedCity(name: "Yokohama", region: "Kanagawa", country: "Japan", latitude: 35.4437, longitude: 139.6380),
        SavedCity(name: "Nagoya", region: "Aichi", country: "Japan", latitude: 35.1815, longitude: 136.9066),
        SavedCity(name: "Sapporo", region: "Hokkaido", country: "Japan", latitude: 43.0618, longitude: 141.3545),
        SavedCity(name: "Fukuoka", region: "Fukuoka", country: "Japan", latitude: 33.5904, longitude: 130.4017),
        SavedCity(name: "Hiroshima", region: "Hiroshima", country: "Japan", latitude: 34.3853, longitude: 132.4553),
        SavedCity(name: "Nara", region: "Nara", country: "Japan", latitude: 34.6851, longitude: 135.8048),
        SavedCity(name: "Seoul", region: "Seoul", country: "South Korea", latitude: 37.5665, longitude: 126.9780),
        SavedCity(name: "Busan", region: "Busan", country: "South Korea", latitude: 35.1796, longitude: 129.0756),
        SavedCity(name: "Incheon", region: "Incheon", country: "South Korea", latitude: 37.4563, longitude: 126.7052),
        SavedCity(name: "Jeju", region: "Jeju", country: "South Korea", latitude: 33.4996, longitude: 126.5312),
        SavedCity(name: "Beijing", region: "Beijing", country: "China", latitude: 39.9042, longitude: 116.4074),
        SavedCity(name: "Shanghai", region: "Shanghai", country: "China", latitude: 31.2304, longitude: 121.4737),
        SavedCity(name: "Guangzhou", region: "Guangdong", country: "China", latitude: 23.1291, longitude: 113.2644),
        SavedCity(name: "Shenzhen", region: "Guangdong", country: "China", latitude: 22.5431, longitude: 114.0579),
        SavedCity(name: "Chengdu", region: "Sichuan", country: "China", latitude: 30.5728, longitude: 104.0668),
        SavedCity(name: "Xi'an", region: "Shaanxi", country: "China", latitude: 34.3416, longitude: 108.9398),
        SavedCity(name: "Hangzhou", region: "Zhejiang", country: "China", latitude: 30.2741, longitude: 120.1551),
        SavedCity(name: "Hong Kong", region: "Hong Kong", country: "China", latitude: 22.3193, longitude: 114.1694),
        SavedCity(name: "Macau", region: "Macau", country: "China", latitude: 22.1987, longitude: 113.5439),
        SavedCity(name: "Taipei", region: "Taiwan", country: "Taiwan", latitude: 25.0330, longitude: 121.5654),
        SavedCity(name: "Kaohsiung", region: "Taiwan", country: "Taiwan", latitude: 22.6273, longitude: 120.3014),
        SavedCity(name: "Ulaanbaatar", region: "Ulaanbaatar", country: "Mongolia", latitude: 47.8864, longitude: 106.9057),

        // Asia - Southeast
        SavedCity(name: "Singapore", region: "Singapore", country: "Singapore", latitude: 1.3521, longitude: 103.8198),
        SavedCity(name: "Bangkok", region: "Bangkok", country: "Thailand", latitude: 13.7563, longitude: 100.5018),
        SavedCity(name: "Chiang Mai", region: "Chiang Mai", country: "Thailand", latitude: 18.7883, longitude: 98.9853),
        SavedCity(name: "Phuket", region: "Phuket", country: "Thailand", latitude: 7.8804, longitude: 98.3923),
        SavedCity(name: "Pattaya", region: "Chonburi", country: "Thailand", latitude: 12.9236, longitude: 100.8825),
        SavedCity(name: "Krabi", region: "Krabi", country: "Thailand", latitude: 8.0863, longitude: 98.9063),
        SavedCity(name: "Ho Chi Minh City", region: "Ho Chi Minh", country: "Vietnam", latitude: 10.8231, longitude: 106.6297),
        SavedCity(name: "Hanoi", region: "Hanoi", country: "Vietnam", latitude: 21.0278, longitude: 105.8342),
        SavedCity(name: "Da Nang", region: "Da Nang", country: "Vietnam", latitude: 16.0544, longitude: 108.2022),
        SavedCity(name: "Hoi An", region: "Quang Nam", country: "Vietnam", latitude: 15.8801, longitude: 108.3380),
        SavedCity(name: "Nha Trang", region: "Khanh Hoa", country: "Vietnam", latitude: 12.2388, longitude: 109.1967),
        SavedCity(name: "Kuala Lumpur", region: "KL", country: "Malaysia", latitude: 3.1390, longitude: 101.6869),
        SavedCity(name: "Penang", region: "Penang", country: "Malaysia", latitude: 5.4141, longitude: 100.3288),
        SavedCity(name: "Langkawi", region: "Kedah", country: "Malaysia", latitude: 6.3500, longitude: 99.8000),
        SavedCity(name: "Jakarta", region: "Jakarta", country: "Indonesia", latitude: -6.2088, longitude: 106.8456),
        SavedCity(name: "Bali", region: "Bali", country: "Indonesia", latitude: -8.3405, longitude: 115.0920),
        SavedCity(name: "Yogyakarta", region: "Yogyakarta", country: "Indonesia", latitude: -7.7956, longitude: 110.3695),
        SavedCity(name: "Surabaya", region: "East Java", country: "Indonesia", latitude: -7.2575, longitude: 112.7521),
        SavedCity(name: "Manila", region: "Metro Manila", country: "Philippines", latitude: 14.5995, longitude: 120.9842),
        SavedCity(name: "Cebu", region: "Central Visayas", country: "Philippines", latitude: 10.3157, longitude: 123.8854),
        SavedCity(name: "Boracay", region: "Western Visayas", country: "Philippines", latitude: 11.9674, longitude: 121.9248),
        SavedCity(name: "Palawan", region: "Mimaropa", country: "Philippines", latitude: 9.8349, longitude: 118.7384),
        SavedCity(name: "Phnom Penh", region: "Phnom Penh", country: "Cambodia", latitude: 11.5564, longitude: 104.9282),
        SavedCity(name: "Siem Reap", region: "Siem Reap", country: "Cambodia", latitude: 13.3633, longitude: 103.8564),
        SavedCity(name: "Vientiane", region: "Vientiane", country: "Laos", latitude: 17.9757, longitude: 102.6331),
        SavedCity(name: "Luang Prabang", region: "Luang Prabang", country: "Laos", latitude: 19.8849, longitude: 102.1347),
        SavedCity(name: "Yangon", region: "Yangon", country: "Myanmar", latitude: 16.8661, longitude: 96.1951),

        // Asia - South
        SavedCity(name: "Mumbai", region: "Maharashtra", country: "India", latitude: 19.0760, longitude: 72.8777),
        SavedCity(name: "Delhi", region: "Delhi", country: "India", latitude: 28.6139, longitude: 77.2090),
        SavedCity(name: "Bangalore", region: "Karnataka", country: "India", latitude: 12.9716, longitude: 77.5946),
        SavedCity(name: "Chennai", region: "Tamil Nadu", country: "India", latitude: 13.0827, longitude: 80.2707),
        SavedCity(name: "Kolkata", region: "West Bengal", country: "India", latitude: 22.5726, longitude: 88.3639),
        SavedCity(name: "Hyderabad", region: "Telangana", country: "India", latitude: 17.3850, longitude: 78.4867),
        SavedCity(name: "Jaipur", region: "Rajasthan", country: "India", latitude: 26.9124, longitude: 75.7873),
        SavedCity(name: "Goa", region: "Goa", country: "India", latitude: 15.2993, longitude: 74.1240),
        SavedCity(name: "Agra", region: "Uttar Pradesh", country: "India", latitude: 27.1767, longitude: 78.0081),
        SavedCity(name: "Varanasi", region: "Uttar Pradesh", country: "India", latitude: 25.3176, longitude: 82.9739),
        SavedCity(name: "Udaipur", region: "Rajasthan", country: "India", latitude: 24.5854, longitude: 73.7125),
        SavedCity(name: "Colombo", region: "Western", country: "Sri Lanka", latitude: 6.9271, longitude: 79.8612),
        SavedCity(name: "Kathmandu", region: "Bagmati", country: "Nepal", latitude: 27.7172, longitude: 85.3240),
        SavedCity(name: "Dhaka", region: "Dhaka", country: "Bangladesh", latitude: 23.8103, longitude: 90.4125),
        SavedCity(name: "Karachi", region: "Sindh", country: "Pakistan", latitude: 24.8607, longitude: 67.0011),
        SavedCity(name: "Lahore", region: "Punjab", country: "Pakistan", latitude: 31.5204, longitude: 74.3587),
        SavedCity(name: "Islamabad", region: "Islamabad", country: "Pakistan", latitude: 33.6844, longitude: 73.0479),
        SavedCity(name: "Malé", region: "Malé", country: "Maldives", latitude: 4.1755, longitude: 73.5093),

        // Asia - Middle East
        SavedCity(name: "Dubai", region: "Dubai", country: "UAE", latitude: 25.2048, longitude: 55.2708),
        SavedCity(name: "Abu Dhabi", region: "Abu Dhabi", country: "UAE", latitude: 24.4539, longitude: 54.3773),
        SavedCity(name: "Doha", region: "Doha", country: "Qatar", latitude: 25.2854, longitude: 51.5310),
        SavedCity(name: "Riyadh", region: "Riyadh", country: "Saudi Arabia", latitude: 24.7136, longitude: 46.6753),
        SavedCity(name: "Jeddah", region: "Makkah", country: "Saudi Arabia", latitude: 21.4858, longitude: 39.1925),
        SavedCity(name: "Muscat", region: "Muscat", country: "Oman", latitude: 23.5880, longitude: 58.3829),
        SavedCity(name: "Kuwait City", region: "Al Asimah", country: "Kuwait", latitude: 29.3759, longitude: 47.9774),
        SavedCity(name: "Manama", region: "Capital", country: "Bahrain", latitude: 26.2285, longitude: 50.5860),
        SavedCity(name: "Tel Aviv", region: "Tel Aviv", country: "Israel", latitude: 32.0853, longitude: 34.7818),
        SavedCity(name: "Jerusalem", region: "Jerusalem", country: "Israel", latitude: 31.7683, longitude: 35.2137),
        SavedCity(name: "Amman", region: "Amman", country: "Jordan", latitude: 31.9454, longitude: 35.9284),
        SavedCity(name: "Beirut", region: "Beirut", country: "Lebanon", latitude: 33.8938, longitude: 35.5018),
        SavedCity(name: "Istanbul", region: "Istanbul", country: "Turkey", latitude: 41.0082, longitude: 28.9784),
        SavedCity(name: "Ankara", region: "Ankara", country: "Turkey", latitude: 39.9334, longitude: 32.8597),
        SavedCity(name: "Antalya", region: "Antalya", country: "Turkey", latitude: 36.8969, longitude: 30.7133),
        SavedCity(name: "Izmir", region: "Izmir", country: "Turkey", latitude: 38.4237, longitude: 27.1428),
        SavedCity(name: "Cappadocia", region: "Nevşehir", country: "Turkey", latitude: 38.6431, longitude: 34.8289),
        SavedCity(name: "Tehran", region: "Tehran", country: "Iran", latitude: 35.6892, longitude: 51.3890),

        // Oceania
        SavedCity(name: "Sydney", region: "NSW", country: "Australia", latitude: -33.8688, longitude: 151.2093),
        SavedCity(name: "Melbourne", region: "VIC", country: "Australia", latitude: -37.8136, longitude: 144.9631),
        SavedCity(name: "Brisbane", region: "QLD", country: "Australia", latitude: -27.4698, longitude: 153.0251),
        SavedCity(name: "Perth", region: "WA", country: "Australia", latitude: -31.9505, longitude: 115.8605),
        SavedCity(name: "Adelaide", region: "SA", country: "Australia", latitude: -34.9285, longitude: 138.6007),
        SavedCity(name: "Gold Coast", region: "QLD", country: "Australia", latitude: -28.0167, longitude: 153.4000),
        SavedCity(name: "Cairns", region: "QLD", country: "Australia", latitude: -16.9186, longitude: 145.7781),
        SavedCity(name: "Hobart", region: "TAS", country: "Australia", latitude: -42.8821, longitude: 147.3272),
        SavedCity(name: "Darwin", region: "NT", country: "Australia", latitude: -12.4634, longitude: 130.8456),
        SavedCity(name: "Canberra", region: "ACT", country: "Australia", latitude: -35.2809, longitude: 149.1300),
        SavedCity(name: "Auckland", region: "Auckland", country: "New Zealand", latitude: -36.8485, longitude: 174.7633),
        SavedCity(name: "Wellington", region: "Wellington", country: "New Zealand", latitude: -41.2865, longitude: 174.7762),
        SavedCity(name: "Christchurch", region: "Canterbury", country: "New Zealand", latitude: -43.5321, longitude: 172.6362),
        SavedCity(name: "Queenstown", region: "Otago", country: "New Zealand", latitude: -45.0312, longitude: 168.6626),
        SavedCity(name: "Rotorua", region: "Bay of Plenty", country: "New Zealand", latitude: -38.1368, longitude: 176.2497),
        SavedCity(name: "Fiji", region: "Suva", country: "Fiji", latitude: -18.1416, longitude: 178.4419),
        SavedCity(name: "Tahiti", region: "Windward Islands", country: "French Polynesia", latitude: -17.6509, longitude: -149.4260),
        SavedCity(name: "Bora Bora", region: "Leeward Islands", country: "French Polynesia", latitude: -16.5004, longitude: -151.7415),

        // South America
        SavedCity(name: "São Paulo", region: "SP", country: "Brazil", latitude: -23.5505, longitude: -46.6333),
        SavedCity(name: "Rio de Janeiro", region: "RJ", country: "Brazil", latitude: -22.9068, longitude: -43.1729),
        SavedCity(name: "Brasília", region: "DF", country: "Brazil", latitude: -15.7975, longitude: -47.8919),
        SavedCity(name: "Salvador", region: "BA", country: "Brazil", latitude: -12.9714, longitude: -38.5014),
        SavedCity(name: "Fortaleza", region: "CE", country: "Brazil", latitude: -3.7172, longitude: -38.5433),
        SavedCity(name: "Recife", region: "PE", country: "Brazil", latitude: -8.0476, longitude: -34.8770),
        SavedCity(name: "Florianópolis", region: "SC", country: "Brazil", latitude: -27.5954, longitude: -48.5480),
        SavedCity(name: "Buenos Aires", region: "BA", country: "Argentina", latitude: -34.6037, longitude: -58.3816),
        SavedCity(name: "Mendoza", region: "Mendoza", country: "Argentina", latitude: -32.8895, longitude: -68.8458),
        SavedCity(name: "Córdoba", region: "Córdoba", country: "Argentina", latitude: -31.4201, longitude: -64.1888),
        SavedCity(name: "Bariloche", region: "Río Negro", country: "Argentina", latitude: -41.1335, longitude: -71.3103),
        SavedCity(name: "Santiago", region: "Santiago", country: "Chile", latitude: -33.4489, longitude: -70.6693),
        SavedCity(name: "Valparaíso", region: "Valparaíso", country: "Chile", latitude: -33.0472, longitude: -71.6127),
        SavedCity(name: "Lima", region: "Lima", country: "Peru", latitude: -12.0464, longitude: -77.0428),
        SavedCity(name: "Cusco", region: "Cusco", country: "Peru", latitude: -13.5319, longitude: -71.9675),
        SavedCity(name: "Machu Picchu", region: "Cusco", country: "Peru", latitude: -13.1631, longitude: -72.5450),
        SavedCity(name: "Bogotá", region: "Bogotá", country: "Colombia", latitude: 4.7110, longitude: -74.0721),
        SavedCity(name: "Medellín", region: "Antioquia", country: "Colombia", latitude: 6.2442, longitude: -75.5812),
        SavedCity(name: "Cartagena", region: "Bolívar", country: "Colombia", latitude: 10.3910, longitude: -75.4794),
        SavedCity(name: "Quito", region: "Pichincha", country: "Ecuador", latitude: -0.1807, longitude: -78.4678),
        SavedCity(name: "Galápagos Islands", region: "Galápagos", country: "Ecuador", latitude: -0.9538, longitude: -90.9656),
        SavedCity(name: "Guayaquil", region: "Guayas", country: "Ecuador", latitude: -2.1894, longitude: -79.8891),
        SavedCity(name: "Montevideo", region: "Montevideo", country: "Uruguay", latitude: -34.9011, longitude: -56.1645),
        SavedCity(name: "Punta del Este", region: "Maldonado", country: "Uruguay", latitude: -34.9667, longitude: -54.9500),
        SavedCity(name: "Caracas", region: "Capital District", country: "Venezuela", latitude: 10.4806, longitude: -66.9036),
        SavedCity(name: "La Paz", region: "La Paz", country: "Bolivia", latitude: -16.4897, longitude: -68.1193),
        SavedCity(name: "Asunción", region: "Asunción", country: "Paraguay", latitude: -25.2637, longitude: -57.5759),

        // Africa
        SavedCity(name: "Cairo", region: "Cairo", country: "Egypt", latitude: 30.0444, longitude: 31.2357),
        SavedCity(name: "Alexandria", region: "Alexandria", country: "Egypt", latitude: 31.2001, longitude: 29.9187),
        SavedCity(name: "Luxor", region: "Luxor", country: "Egypt", latitude: 25.6872, longitude: 32.6396),
        SavedCity(name: "Sharm El Sheikh", region: "South Sinai", country: "Egypt", latitude: 27.9158, longitude: 34.3300),
        SavedCity(name: "Marrakech", region: "Marrakech-Safi", country: "Morocco", latitude: 31.6295, longitude: -7.9811),
        SavedCity(name: "Casablanca", region: "Casablanca-Settat", country: "Morocco", latitude: 33.5731, longitude: -7.5898),
        SavedCity(name: "Fes", region: "Fès-Meknès", country: "Morocco", latitude: 34.0181, longitude: -5.0078),
        SavedCity(name: "Tangier", region: "Tanger-Tetouan-Al Hoceima", country: "Morocco", latitude: 35.7595, longitude: -5.8340),
        SavedCity(name: "Tunis", region: "Tunis", country: "Tunisia", latitude: 36.8065, longitude: 10.1815),
        SavedCity(name: "Cape Town", region: "Western Cape", country: "South Africa", latitude: -33.9249, longitude: 18.4241),
        SavedCity(name: "Johannesburg", region: "Gauteng", country: "South Africa", latitude: -26.2041, longitude: 28.0473),
        SavedCity(name: "Durban", region: "KwaZulu-Natal", country: "South Africa", latitude: -29.8587, longitude: 31.0218),
        SavedCity(name: "Pretoria", region: "Gauteng", country: "South Africa", latitude: -25.7479, longitude: 28.2293),
        SavedCity(name: "Kruger National Park", region: "Limpopo", country: "South Africa", latitude: -23.9884, longitude: 31.5547),
        SavedCity(name: "Nairobi", region: "Nairobi", country: "Kenya", latitude: -1.2921, longitude: 36.8219),
        SavedCity(name: "Mombasa", region: "Coast", country: "Kenya", latitude: -4.0435, longitude: 39.6682),
        SavedCity(name: "Maasai Mara", region: "Narok", country: "Kenya", latitude: -1.4061, longitude: 35.0172),
        SavedCity(name: "Zanzibar", region: "Zanzibar", country: "Tanzania", latitude: -6.1659, longitude: 39.2026),
        SavedCity(name: "Dar es Salaam", region: "Dar es Salaam", country: "Tanzania", latitude: -6.7924, longitude: 39.2083),
        SavedCity(name: "Serengeti", region: "Mara", country: "Tanzania", latitude: -2.3333, longitude: 34.8333),
        SavedCity(name: "Lagos", region: "Lagos", country: "Nigeria", latitude: 6.5244, longitude: 3.3792),
        SavedCity(name: "Abuja", region: "FCT", country: "Nigeria", latitude: 9.0765, longitude: 7.3986),
        SavedCity(name: "Accra", region: "Greater Accra", country: "Ghana", latitude: 5.6037, longitude: -0.1870),
        SavedCity(name: "Addis Ababa", region: "Addis Ababa", country: "Ethiopia", latitude: 9.0320, longitude: 38.7469),
        SavedCity(name: "Dakar", region: "Dakar", country: "Senegal", latitude: 14.7167, longitude: -17.4677),
        SavedCity(name: "Victoria Falls", region: "Matabeleland North", country: "Zimbabwe", latitude: -17.9243, longitude: 25.8572),
        SavedCity(name: "Mauritius", region: "Port Louis", country: "Mauritius", latitude: -20.1609, longitude: 57.5012),
        SavedCity(name: "Seychelles", region: "Mahé", country: "Seychelles", latitude: -4.6796, longitude: 55.4920),
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

        // If only the current city remains in savedCities, remove it too
        // This returns to the "single city" empty state
        if savedCities.count == 1 && savedCities.first?.id == currentCity.id {
            savedCities.removeAll()
        }

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
