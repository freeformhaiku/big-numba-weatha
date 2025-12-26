import SwiftUI

// MARK: - Custom Colors
extension Color {
    static let unitSelectedText = Color(red: 61.0/255.0, green: 63.0/255.0, blue: 208.0/255.0)    // #3D3FD0
    static let unitSelectedCheck = Color(red: 106.0/255.0, green: 108.0/255.0, blue: 255.0/255.0) // #6A6CFF
    static let chartStroke = Color(red: 121.0/255.0, green: 75.0/255.0, blue: 196.0/255.0)        // #794BC4
    static let chartFill = Color(red: 228.0/255.0, green: 197.0/255.0, blue: 255.0/255.0)         // #E4C5FF (keeping for reference)
    
    // Dark mode card background: #222222
    static let cardBackgroundDark = Color(red: 34.0/255.0, green: 34.0/255.0, blue: 34.0/255.0)
    
    // Dark mode secondary text: #9A9A9A
    static let secondaryTextDark = Color(red: 154.0/255.0, green: 154.0/255.0, blue: 154.0/255.0)
    
    // Dark mode screen background: #111111
    static let screenBackgroundDark = Color(red: 17.0/255.0, green: 17.0/255.0, blue: 17.0/255.0)
    
    // Dark mode current time dot: #D5BBFF
    static let currentTimeDotDark = Color(red: 213.0/255.0, green: 187.0/255.0, blue: 255.0/255.0)
    
    static func currentTimeDot(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? currentTimeDotDark : chartStroke
    }
    
    // Edit button background: #555555
    static let editButtonBackground = Color(red: 85.0/255.0, green: 85.0/255.0, blue: 85.0/255.0)
    
    // Add city button purple (same as chart stroke)
    static let addCityButtonPurple = Color(red: 121.0/255.0, green: 75.0/255.0, blue: 196.0/255.0)  // #794BC4
    
    // Adaptive colors that change based on color scheme
    static func screenBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? screenBackgroundDark : Color(UIColor.systemGroupedBackground)
    }
    
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? cardBackgroundDark : Color(UIColor.systemBackground)
    }
    
    static func chevronBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? cardBackgroundDark : Color(red: 229.0/255.0, green: 229.0/255.0, blue: 229.0/255.0)
    }
    
    static func unitButtonBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? cardBackgroundDark : Color(red: 229.0/255.0, green: 229.0/255.0, blue: 229.0/255.0)
    }
    
    static func unitButtonPressed(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 50.0/255.0, green: 50.0/255.0, blue: 50.0/255.0) : Color(red: 210.0/255.0, green: 210.0/255.0, blue: 210.0/255.0)
    }
    
    static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .primary
    }
    
    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? secondaryTextDark : .secondary
    }
    
    static func chartFillTop(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 80.0/255.0, green: 60.0/255.0, blue: 100.0/255.0) : Color(red: 228.0/255.0, green: 213.0/255.0, blue: 242.0/255.0)
    }
    
    static func chartFillBottom(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? cardBackgroundDark.opacity(0) : Color.white.opacity(0)
    }
}

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { newValue in
                isPressed = newValue
            }
    }
}

struct HomeScreen: View {
    @StateObject private var viewModel = WeatherViewModel()
    @State private var showCityPicker = false
    @State private var isUnitButtonPressed = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    
    // This ID changes to force the chart to redraw when app becomes active
    @State private var refreshID = UUID()
    
    // Track which city index is selected for swiping
    @State private var selectedCityIndex: Int = 0
    
    var body: some View {
        ZStack {
            // Background
            Color.screenBackground(for: colorScheme)
                .ignoresSafeArea()
            
            if viewModel.savedCities.isEmpty {
                // No saved cities yet - show single city view (non-swipeable)
                SingleCityView(
                    viewModel: viewModel,
                    showCityPicker: $showCityPicker,
                    isUnitButtonPressed: $isUnitButtonPressed,
                    refreshID: $refreshID,
                    colorScheme: colorScheme
                )
            } else {
                // Multiple cities - swipeable TabView
                TabView(selection: $selectedCityIndex) {
                    ForEach(Array(viewModel.savedCities.enumerated()), id: \.element.id) { index, city in
                        CityWeatherPage(
                            viewModel: viewModel,
                            city: city,
                            showCityPicker: $showCityPicker,
                            isUnitButtonPressed: $isUnitButtonPressed,
                            refreshID: $refreshID,
                            colorScheme: colorScheme
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: selectedCityIndex) { newIndex in
                    // When user swipes to a different city, update the viewModel
                    if newIndex >= 0 && newIndex < viewModel.savedCities.count {
                        let city = viewModel.savedCities[newIndex]
                        if city.id != viewModel.currentCity.id {
                            Task {
                                await viewModel.selectCity(city)
                            }
                        }
                    }
                }
            }
        }
        .task {
            // Fetch weather when the view appears
            await viewModel.fetchWeather()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Force chart to redraw with current time when app becomes active
                refreshID = UUID()
            }
        }
        .onChange(of: viewModel.currentCity.id) { _ in
            // Sync selectedCityIndex when currentCity changes (e.g., from My Cities tap)
            if let index = viewModel.savedCities.firstIndex(where: { $0.id == viewModel.currentCity.id }) {
                if selectedCityIndex != index {
                    selectedCityIndex = index
                }
            }
        }
        .onChange(of: viewModel.savedCities.count) { _ in
            // When cities are added, update the selected index to match current city
            if let index = viewModel.savedCities.firstIndex(where: { $0.id == viewModel.currentCity.id }) {
                selectedCityIndex = index
            }
        }
        .sheet(isPresented: $showCityPicker) {
            CityPickerSheet(viewModel: viewModel)
        }
    }
}

// MARK: - Single City View (when no saved cities yet)

struct SingleCityView: View {
    @ObservedObject var viewModel: WeatherViewModel
    @Binding var showCityPicker: Bool
    @Binding var isUnitButtonPressed: Bool
    @Binding var refreshID: UUID
    let colorScheme: ColorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                WeatherHeader(
                    viewModel: viewModel,
                    isUnitButtonPressed: $isUnitButtonPressed,
                    colorScheme: colorScheme
                )
                
                // Today's Weather
                if let today = viewModel.todayWeather {
                    TodayWeatherCard(
                        weather: today,
                        yesterdayWeather: viewModel.yesterdayWeather,
                        city: viewModel.currentCity,
                        unit: viewModel.temperatureUnit,
                        onCityTap: { showCityPicker = true },
                        colorScheme: colorScheme
                    )
                } else if viewModel.isLoading {
                    LoadingCard(height: 200)
                }
                
                // Temp by Hour Chart
                if let yesterday = viewModel.yesterdayWeather,
                   let today = viewModel.todayWeather,
                   let tomorrow = viewModel.tomorrowWeather {
                    ThreeDayHourlyChart(
                        yesterday: yesterday,
                        today: today,
                        tomorrow: tomorrow,
                        colorScheme: colorScheme
                    )
                    .id(refreshID)
                    .padding(.top, -8)
                }
                
                // Yesterday & Tomorrow Row
                HStack(spacing: 12) {
                    if let yesterday = viewModel.yesterdayWeather {
                        SecondaryWeatherCard(weather: yesterday, colorScheme: colorScheme)
                    } else if viewModel.isLoading {
                        LoadingCard(height: 140)
                    }
                    
                    if let tomorrow = viewModel.tomorrowWeather {
                        SecondaryWeatherCard(weather: tomorrow, colorScheme: colorScheme)
                    } else if viewModel.isLoading {
                        LoadingCard(height: 140)
                    }
                }
                
                // My Cities Section - Empty State
                MyCitiesSection(
                    viewModel: viewModel,
                    showCityPicker: $showCityPicker,
                    colorScheme: colorScheme
                )
                
                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
        .refreshable {
            await viewModel.fetchWeather()
        }
    }
}

// MARK: - City Weather Page (for swipeable TabView)

struct CityWeatherPage: View {
    @ObservedObject var viewModel: WeatherViewModel
    let city: SavedCity
    @Binding var showCityPicker: Bool
    @Binding var isUnitButtonPressed: Bool
    @Binding var refreshID: UUID
    let colorScheme: ColorScheme
    
    // Check if this page is for the current city
    private var isCurrentCity: Bool {
        city.id == viewModel.currentCity.id
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                WeatherHeader(
                    viewModel: viewModel,
                    isUnitButtonPressed: $isUnitButtonPressed,
                    colorScheme: colorScheme
                )
                
                // Today's Weather - show data only if this is the current city
                if isCurrentCity, let today = viewModel.todayWeather {
                    TodayWeatherCard(
                        weather: today,
                        yesterdayWeather: viewModel.yesterdayWeather,
                        city: city,
                        unit: viewModel.temperatureUnit,
                        onCityTap: { showCityPicker = true },
                        colorScheme: colorScheme
                    )
                } else if viewModel.isLoading {
                    LoadingCard(height: 200)
                } else {
                    // Show placeholder while loading this city's data
                    LoadingCard(height: 200)
                }
                
                // Temp by Hour Chart
                if isCurrentCity,
                   let yesterday = viewModel.yesterdayWeather,
                   let today = viewModel.todayWeather,
                   let tomorrow = viewModel.tomorrowWeather {
                    ThreeDayHourlyChart(
                        yesterday: yesterday,
                        today: today,
                        tomorrow: tomorrow,
                        colorScheme: colorScheme
                    )
                    .id(refreshID)
                    .padding(.top, -8)
                }
                
                // Yesterday & Tomorrow Row
                if isCurrentCity {
                    HStack(spacing: 12) {
                        if let yesterday = viewModel.yesterdayWeather {
                            SecondaryWeatherCard(weather: yesterday, colorScheme: colorScheme)
                        } else if viewModel.isLoading {
                            LoadingCard(height: 140)
                        }
                        
                        if let tomorrow = viewModel.tomorrowWeather {
                            SecondaryWeatherCard(weather: tomorrow, colorScheme: colorScheme)
                        } else if viewModel.isLoading {
                            LoadingCard(height: 140)
                        }
                    }
                }
                
                // My Cities Section
                MyCitiesSection(
                    viewModel: viewModel,
                    showCityPicker: $showCityPicker,
                    colorScheme: colorScheme
                )
                
                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
        .refreshable {
            await viewModel.fetchWeather()
        }
    }
}

// MARK: - Weather Header

struct WeatherHeader: View {
    @ObservedObject var viewModel: WeatherViewModel
    @Binding var isUnitButtonPressed: Bool
    let colorScheme: ColorScheme
    
    var body: some View {
        ZStack {
            // Centered title with app icon
            HStack(spacing: 8) {
                Image("app-icon-small")
                    .resizable()
                    .frame(width: 24, height: 24)
                Text("big numba weatha")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(Color.primaryText(for: colorScheme))
            }
            
            // Right-aligned unit button
            HStack {
                Spacer()
                
                Button(action: {
                    Task {
                        let newUnit: TemperatureUnit = viewModel.temperatureUnit == .celsius ? .fahrenheit : .celsius
                        await viewModel.setTemperatureUnit(newUnit)
                    }
                }) {
                    Text(viewModel.temperatureUnit.symbol)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.primaryText(for: colorScheme))
                        .frame(width: 36)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isUnitButtonPressed ? Color.unitButtonPressed(for: colorScheme) : Color.unitButtonBackground(for: colorScheme))
                        )
                }
                .buttonStyle(PressableButtonStyle(isPressed: $isUnitButtonPressed))
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - My Cities Section

struct MyCitiesSection: View {
    @ObservedObject var viewModel: WeatherViewModel
    @Binding var showCityPicker: Bool
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Edit button
            HStack {
                Text("My Cities")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.primaryText(for: colorScheme))
                
                Spacer()
                
                if !viewModel.savedCities.isEmpty {
                    Button(action: {
                        // Edit functionality to be added later
                    }) {
                        Text("Edit")
                            .font(.footnote)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.editButtonBackground)
                            .cornerRadius(14)
                    }
                }
            }
            
            if viewModel.savedCities.isEmpty {
                // Empty state - Add a city card
                Button(action: {
                    showCityPicker = true
                }) {
                    VStack(spacing: 12) {
                        Circle()
                            .fill(Color.addCityButtonPurple)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(.white)
                            )
                        
                        Text("Add a city")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(Color.primaryText(for: colorScheme))
                        
                        Text("Search for a city to add it to your list")
                            .font(.subheadline)
                            .foregroundColor(Color.secondaryText(for: colorScheme))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.cardBackground(for: colorScheme))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Populated state - Separate card for each city
                ForEach(viewModel.savedCities) { city in
                    SavedCityRow(
                        city: city,
                        weather: viewModel.savedCityWeather[city.id.uuidString],
                        colorScheme: colorScheme
                    )
                    .background(Color.cardBackground(for: colorScheme))
                    .cornerRadius(12)
                    .onTapGesture {
                        Task {
                            await viewModel.selectCity(city)
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}

// Helper for rounded corners on specific sides
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Today's Weather Card (Primary)

struct TodayWeatherCard: View {
    let weather: DayWeather
    let yesterdayWeather: DayWeather?
    let city: SavedCity
    let unit: TemperatureUnit
    let onCityTap: () -> Void
    let colorScheme: ColorScheme
    
    /// Generates the comparison text like "2 degrees cooler than yesterday"
    /// Compares the average temperature (high + low / 2) of today vs yesterday
    var comparisonText: String? {
        guard let yesterday = yesterdayWeather else { return nil }
        
        // Calculate average temps for a more accurate "feel" comparison
        let todayAverage = Double(weather.highTemp + weather.lowTemp) / 2.0
        let yesterdayAverage = Double(yesterday.highTemp + yesterday.lowTemp) / 2.0
        let difference = todayAverage - yesterdayAverage
        
        // Round to nearest 0.5 for display, but show as integer if it's a whole number
        let roundedDiff = (difference * 2).rounded() / 2  // Rounds to nearest 0.5
        
        if abs(roundedDiff) < 0.5 {
            return "Same as yesterday"
        } else if roundedDiff > 0 {
            let displayDiff = roundedDiff.truncatingRemainder(dividingBy: 1) == 0 
                ? String(format: "%.0f", roundedDiff) 
                : String(format: "%.1f", roundedDiff)
            let degreeWord = abs(roundedDiff) == 1 ? "degree" : "degrees"
            return "\(displayDiff) \(degreeWord) warmer than yesterday"
        } else {
            let absDiff = abs(roundedDiff)
            let displayDiff = absDiff.truncatingRemainder(dividingBy: 1) == 0 
                ? String(format: "%.0f", absDiff) 
                : String(format: "%.1f", absDiff)
            let degreeWord = absDiff == 1 ? "degree" : "degrees"
            return "\(displayDiff) \(degreeWord) cooler than yesterday"
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Date
            Text(weather.date.fullDateString)
                .font(.body)
                .foregroundColor(Color.secondaryText(for: colorScheme))
            
            // Big temperature number (with invisible left spacer to visually center)
            HStack(alignment: .top, spacing: 2) {
                // Invisible spacer matching the °C/°F size
                Text(unit.symbol)
                    .font(.title2)
                    .foregroundColor(.clear)
                    .padding(.top, 12)
                
                Text("\(weather.currentTemp ?? weather.highTemp)")
                    .font(.system(size: 80, weight: .regular))
                    .foregroundColor(Color.primaryText(for: colorScheme))
                
                Text(unit.symbol)
                    .font(.title2)
                    .foregroundColor(Color.primaryText(for: colorScheme))
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            // High / Low
            HStack(spacing: 16) {
                Text("\(weather.lowTemp)°")
                    .foregroundColor(Color.secondaryText(for: colorScheme))
                Text("\(weather.highTemp)°")
                    .foregroundColor(Color.primaryText(for: colorScheme))
            }
            .font(.title3)
            .frame(maxWidth: .infinity, alignment: .center)
            
            // Weather condition and comparison
            HStack(spacing: 6) {
                Text(weather.condition.displayName)
                    .foregroundColor(Color.secondaryText(for: colorScheme))
                
                if let comparison = comparisonText {
                    Text("•")
                        .foregroundColor(Color.secondaryText(for: colorScheme))
                    Text(comparison)
                        .foregroundColor(Color.secondaryText(for: colorScheme))
                }
            }
            .font(.subheadline)
            
            // City with dropdown indicator
            Button(action: onCityTap) {
                HStack(spacing: 6) {
                    // Show country emoji for special countries
                    if city.isInCanada {
                        Text("🍁")
                    } else if city.isInPoland {
                        Text("🥒")
                    }
                    
                    Text(city.displayName)
                        .foregroundColor(Color.secondaryText(for: colorScheme))
                    
                    // Dropdown indicator with custom colors
                    Circle()
                        .fill(Color.chevronBackground(for: colorScheme))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(Color.secondaryText(for: colorScheme))
                        )
                }
                .font(.body)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground(for: colorScheme))
        .cornerRadius(16)
    }
}

// MARK: - Secondary Weather Card (Yesterday/Tomorrow)

struct SecondaryWeatherCard: View {
    let weather: DayWeather
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            // Abbreviated date
            Text(weather.date.abbreviatedDateString)
                .font(.subheadline)
                .foregroundColor(Color.secondaryText(for: colorScheme))
            
            // Weather icon - fixed frame for consistent card heights
            WeatherIcon(condition: weather.condition, colorScheme: colorScheme)
                .frame(width: 40, height: 40)
            
            // Weather condition label
            Text(weather.condition.displayName)
                .font(.subheadline)
                .foregroundColor(Color.secondaryText(for: colorScheme))
            
            // High / Low
            HStack(spacing: 12) {
                Text("\(weather.lowTemp)°")
                    .foregroundColor(Color.secondaryText(for: colorScheme))
                Text("\(weather.highTemp)°")
                    .fontWeight(.medium)
                    .foregroundColor(Color.primaryText(for: colorScheme))
            }
            .font(.title3)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground(for: colorScheme))
        .cornerRadius(12)
    }
}

// MARK: - Weather Icon (supports both SF Symbols and custom PNGs)

struct WeatherIcon: View {
    let condition: WeatherCondition
    var size: CGFloat = 32
    var colorScheme: ColorScheme = .light
    
    var body: some View {
        if WeatherCondition.useCustomIcons {
            // Custom PNG from Assets.xcassets
            Image(condition.customIconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            // SF Symbol
            Image(systemName: condition.sfSymbolName)
                .font(.system(size: size))
                .foregroundColor(Color.secondaryText(for: colorScheme))
        }
    }
}

// MARK: - Saved City Row (for My Cities section)

struct SavedCityRow: View {
    let city: SavedCity
    let weather: CityWeatherSummary?
    let colorScheme: ColorScheme
    
    /// Formats the current time in the city's timezone
    private var localTimeString: String {
        guard let weather = weather else { return "--" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        
        if let timezone = TimeZone(identifier: weather.timezone) {
            formatter.timeZone = timezone
        }
        
        return formatter.string(from: Date())
    }
    
    var body: some View {
        HStack {
            // Left side: City name, time, weather condition
            VStack(alignment: .leading, spacing: 4) {
                Text(city.name)
                    .font(.callout)
                    .fontWeight(.bold)
                    .foregroundColor(Color.primaryText(for: colorScheme))
                
                Text(localTimeString)
                    .font(.footnote)
                    .foregroundColor(Color.secondaryText(for: colorScheme))
                
                if let weather = weather {
                    Text(weather.condition.displayName)
                        .font(.footnote)
                        .foregroundColor(Color.secondaryText(for: colorScheme))
                }
            }
            
            Spacer()
            
            // Right side: Current temp and high/low
            if let weather = weather {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(weather.currentTemp)°")
                        .font(.largeTitle)
                        .fontWeight(.regular)
                        .foregroundColor(Color.primaryText(for: colorScheme))
                    
                    HStack(spacing: 4) {
                        Text("\(weather.lowTemp)°")
                            .foregroundColor(Color.secondaryText(for: colorScheme))
                        Text("\(weather.highTemp)°")
                            .foregroundColor(Color.primaryText(for: colorScheme))
                    }
                    .font(.footnote)
                }
            } else {
                Text("--°")
                    .font(.largeTitle)
                    .foregroundColor(Color.secondaryText(for: colorScheme))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Loading Placeholder

struct LoadingCard: View {
    var height: CGFloat = 140
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(UIColor.systemBackground))
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .overlay(
                ProgressView()
            )
    }
}

// MARK: - City Picker Sheet

struct CityPickerSheet: View {
    @ObservedObject var viewModel: WeatherViewModel
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    /// Filter preset cities based on search text
    var filteredCities: [SavedCity] {
        if searchText.isEmpty {
            return WeatherViewModel.presetCities
        } else {
            return WeatherViewModel.presetCities.filter { city in
                city.name.localizedCaseInsensitiveContains(searchText) ||
                city.country.localizedCaseInsensitiveContains(searchText) ||
                city.region.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Search field
                Section {
                    TextField("Search cities...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                
                // Cities list (filtered by search)
                Section(searchText.isEmpty ? "All Cities" : "Results") {
                    ForEach(filteredCities) { city in
                        Button {
                            // Dismiss immediately, then add city in background
                            dismiss()
                            Task {
                                // Add current city to My Cities if not already there
                                let currentCity = viewModel.currentCity
                                if !viewModel.savedCities.contains(where: { $0.name == currentCity.name && $0.region == currentCity.region }) {
                                    await viewModel.addCity(currentCity)
                                }
                                
                                // Add new city and switch to it
                                await viewModel.addCityAndSelect(city)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(city.name)
                                        .foregroundColor(.primary)
                                    Text(city.country)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // Show checkmark for current city
                                if city.name == viewModel.currentCity.name && 
                                   city.country == viewModel.currentCity.country {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Three Day Hourly Chart (72-hour continuous)

struct ThreeDayHourlyChart: View {
    let yesterday: DayWeather
    let today: DayWeather
    let tomorrow: DayWeather
    let colorScheme: ColorScheme
    
    /// Combine all hourly temps into a single 72-hour array
    private var allHourlyTemps: [(dayIndex: Int, hour: Int, temp: Double)] {
        var temps: [(dayIndex: Int, hour: Int, temp: Double)] = []
        
        // Day 0 = Yesterday, Day 1 = Today, Day 2 = Tomorrow
        for hourlyTemp in yesterday.hourlyTemps {
            temps.append((dayIndex: 0, hour: hourlyTemp.hour, temp: hourlyTemp.temp))
        }
        for hourlyTemp in today.hourlyTemps {
            temps.append((dayIndex: 1, hour: hourlyTemp.hour, temp: hourlyTemp.temp))
        }
        for hourlyTemp in tomorrow.hourlyTemps {
            temps.append((dayIndex: 2, hour: hourlyTemp.hour, temp: hourlyTemp.temp))
        }
        
        // Sort by day and hour
        return temps.sorted { 
            if $0.dayIndex != $1.dayIndex {
                return $0.dayIndex < $1.dayIndex
            }
            return $0.hour < $1.hour
        }
    }
    
    /// Get min and max temps for scaling, rounded to nearest 10 with minimal padding
    private var tempRange: (min: Double, max: Double) {
        let temps = allHourlyTemps.map { $0.temp }
        guard !temps.isEmpty else { return (-10, 10) }
        let minTemp = temps.min() ?? 0
        let maxTemp = temps.max() ?? 10
        
        // Round down to nearest 10 for min, round up to nearest 10 for max
        // This gives us clean gridlines without excessive padding
        let roundedMin = floor(minTemp / 10) * 10
        let roundedMax = ceil(maxTemp / 10) * 10
        
        // Ensure we have at least some range
        if roundedMin == roundedMax {
            return (roundedMin - 10, roundedMax + 10)
        }
        
        return (roundedMin, roundedMax)
    }
    
    /// Get the 10-degree intervals for gridlines and y-axis labels
    private var gridlineValues: [Int] {
        let minVal = Int(tempRange.min)
        let maxVal = Int(tempRange.max)
        var values: [Int] = []
        var current = minVal
        while current <= maxVal {
            values.append(current)
            current += 10
        }
        return values
    }
    
    /// Current hour position (0-72 range, where 24 = start of today)
    private var currentHourPosition: CGFloat {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        // Today is dayIndex 1, so offset by 24 hours
        return CGFloat(24 + hour) + CGFloat(minute) / 60.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Temp by hour")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundColor(Color.primaryText(for: colorScheme))
                .padding(.top, 8)
            
            VStack(spacing: 4) {
                // Chart with Y-axis
                HStack(alignment: .top, spacing: 8) {
                    // Y-axis labels (10-degree intervals)
                    VStack {
                        ForEach(gridlineValues.reversed(), id: \.self) { value in
                            if value == gridlineValues.reversed().first {
                                Text("\(value)°")
                            } else {
                                Spacer()
                                Text("\(value)°")
                            }
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(Color.secondaryText(for: colorScheme))
                    .frame(width: 32, height: 100)
                    
                    // Chart
                    GeometryReader { geometry in
                        let width = geometry.size.width
                        let height = geometry.size.height
                        
                        ZStack {
                            // Horizontal gridlines at 10-degree intervals
                            ForEach(gridlineValues, id: \.self) { value in
                                let yPosition = getYPosition(for: Double(value), height: height)
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: yPosition))
                                    path.addLine(to: CGPoint(x: width, y: yPosition))
                                }
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            }
                            
                            // Fill area under the line with gradient
                            ContinuousTemperatureFillShape(
                                data: allHourlyTemps,
                                tempRange: tempRange,
                                width: width,
                                height: height
                            )
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.chartFillTop(for: colorScheme), Color.chartFillBottom(for: colorScheme)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            
                            // Line stroke
                            ContinuousTemperatureLineShape(
                                data: allHourlyTemps,
                                tempRange: tempRange,
                                width: width,
                                height: height
                            )
                            .stroke(Color.chartStroke, lineWidth: 2)
                            
                            // Current time dot
                            if let currentPoint = getCurrentTimePoint(width: width, height: height) {
                                Circle()
                                    .fill(Color.currentTimeDot(for: colorScheme))
                                    .frame(width: 8, height: 8)
                                    .position(currentPoint)
                            }
                        }
                    }
                    .frame(height: 100)
                }
                
                // X-axis time labels
                HStack(spacing: 0) {
                    // Spacer for Y-axis width
                    Color.clear.frame(width: 40)
                    
                    // Time labels across the 72 hours
                    HStack {
                        Text("12a")
                        Spacer()
                        Text("12p")
                        Spacer()
                        Text("12a")
                        Spacer()
                        Text("12p")
                        Spacer()
                        Text("12a")
                        Spacer()
                        Text("12p")
                        Spacer()
                        Text("12a")
                    }
                    .font(.caption2)
                    .foregroundColor(Color.secondaryText(for: colorScheme))
                }
                
                // Day labels
                HStack(spacing: 0) {
                    // Spacer for Y-axis width
                    Color.clear.frame(width: 40)
                    
                    HStack {
                        Text("Yesterday")
                        Spacer()
                        Text("Today")
                        Spacer()
                        Text("Tomorrow")
                    }
                    .font(.caption)
                    .foregroundColor(Color.secondaryText(for: colorScheme))
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(Color.cardBackground(for: colorScheme))
            .cornerRadius(12)
        }
    }
    
    /// Get Y position for a temperature value
    private func getYPosition(for temp: Double, height: CGFloat) -> CGFloat {
        let tempRangeSpan = tempRange.max - tempRange.min
        let yRatio = tempRangeSpan > 0 ? (temp - tempRange.min) / tempRangeSpan : 0.5
        return height * (1 - yRatio)
    }
    
    /// Get the CGPoint for the current time (interpolated to sit exactly on the line)
    private func getCurrentTimePoint(width: CGFloat, height: CGFloat) -> CGPoint? {
        let totalHours: CGFloat = 72
        let x = (currentHourPosition / totalHours) * width
        
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let minuteFraction = Double(currentMinute) / 60.0
        
        // Get current hour's temp (dayIndex 1 = today)
        guard let currentHourData = allHourlyTemps.first(where: { $0.dayIndex == 1 && $0.hour == currentHour }) else {
            return nil
        }
        
        // Get next hour's temp for interpolation
        let nextHour = (currentHour + 1) % 24
        let nextDayIndex = currentHour == 23 ? 2 : 1  // If it's 11pm, next hour is tomorrow
        
        let interpolatedTemp: Double
        if let nextHourData = allHourlyTemps.first(where: { $0.dayIndex == nextDayIndex && $0.hour == nextHour }) {
            // Interpolate between current and next hour based on minutes
            interpolatedTemp = currentHourData.temp + (nextHourData.temp - currentHourData.temp) * minuteFraction
        } else {
            // If no next hour data, just use current hour
            interpolatedTemp = currentHourData.temp
        }
        
        let tempRangeSpan = tempRange.max - tempRange.min
        let yRatio = tempRangeSpan > 0 ? (interpolatedTemp - tempRange.min) / tempRangeSpan : 0.5
        let y = height * (1 - yRatio)
        
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Continuous Chart Shapes (72-hour)

struct ContinuousTemperatureLineShape: Shape {
    let data: [(dayIndex: Int, hour: Int, temp: Double)]
    let tempRange: (min: Double, max: Double)
    let width: CGFloat
    let height: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard data.count >= 2 else { return path }
        
        let points = calculatePoints()
        guard let firstPoint = points.first else { return path }
        
        // Start from the left edge (x=0) at the first point's y-level
        path.move(to: CGPoint(x: 0, y: firstPoint.y))
        
        // Draw through all data points
        for point in points {
            path.addLine(to: point)
        }
        
        // Extend to the right edge at the last point's y-level
        if let lastPoint = points.last {
            path.addLine(to: CGPoint(x: width, y: lastPoint.y))
        }
        
        return path
    }
    
    private func calculatePoints() -> [CGPoint] {
        let totalHours: CGFloat = 72
        
        return data.map { item in
            let hourPosition = CGFloat(item.dayIndex * 24 + item.hour)
            let x = (hourPosition / totalHours) * width
            
            let tempRangeSpan = tempRange.max - tempRange.min
            let yRatio = tempRangeSpan > 0 ? (item.temp - tempRange.min) / tempRangeSpan : 0.5
            let y = height * (1 - yRatio)
            
            return CGPoint(x: x, y: y)
        }
    }
}

struct ContinuousTemperatureFillShape: Shape {
    let data: [(dayIndex: Int, hour: Int, temp: Double)]
    let tempRange: (min: Double, max: Double)
    let width: CGFloat
    let height: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard data.count >= 2 else { return path }
        
        let points = calculatePoints()
        guard let firstPoint = points.first, let lastPoint = points.last else { return path }
        
        // Start from bottom-left corner
        path.move(to: CGPoint(x: 0, y: height))
        
        // Go up to first data point's y-level at x=0
        path.addLine(to: CGPoint(x: 0, y: firstPoint.y))
        
        // Draw line through all points
        for point in points {
            path.addLine(to: point)
        }
        
        // Extend to the right edge at the last point's y-level
        path.addLine(to: CGPoint(x: width, y: lastPoint.y))
        
        // Go down to bottom-right corner
        path.addLine(to: CGPoint(x: width, y: height))
        
        // Close the path
        path.closeSubpath()
        
        return path
    }
    
    private func calculatePoints() -> [CGPoint] {
        let totalHours: CGFloat = 72
        
        return data.map { item in
            let hourPosition = CGFloat(item.dayIndex * 24 + item.hour)
            let x = (hourPosition / totalHours) * width
            
            let tempRangeSpan = tempRange.max - tempRange.min
            let yRatio = tempRangeSpan > 0 ? (item.temp - tempRange.min) / tempRangeSpan : 0.5
            let y = height * (1 - yRatio)
            
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Preview

#Preview {
    HomeScreen()
}
