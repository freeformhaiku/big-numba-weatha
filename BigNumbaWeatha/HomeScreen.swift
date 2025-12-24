import SwiftUI

// MARK: - Custom Colors
extension Color {
    static let unitSelectedText = Color(red: 61.0/255.0, green: 63.0/255.0, blue: 208.0/255.0)    // #3D3FD0
    static let unitSelectedCheck = Color(red: 106.0/255.0, green: 108.0/255.0, blue: 255.0/255.0) // #6A6CFF
    static let chevronBackground = Color(red: 229.0/255.0, green: 229.0/255.0, blue: 229.0/255.0) // #E5E5E5
    static let chevronIcon = Color(red: 122.0/255.0, green: 122.0/255.0, blue: 122.0/255.0)       // #7A7A7A
    static let unitButtonBackground = Color(red: 229.0/255.0, green: 229.0/255.0, blue: 229.0/255.0) // #E5E5E5
    static let unitButtonPressed = Color(red: 210.0/255.0, green: 210.0/255.0, blue: 210.0/255.0)    // #D2D2D2
    static let chartStroke = Color(red: 121.0/255.0, green: 75.0/255.0, blue: 196.0/255.0)        // #794BC4
    static let chartFill = Color(red: 228.0/255.0, green: 197.0/255.0, blue: 255.0/255.0)         // #E4C5FF
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
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    
                    // Header with title and unit toggle
                    ZStack {
                        // Centered title with app icon
                        HStack(spacing: 8) {
                            Image("app-icon-small")
                                .resizable()
                                .frame(width: 24, height: 24)
                            Text("big numba weatha")
                                .font(.title2)
                                .fontWeight(.medium)
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
                                    .foregroundColor(.primary)
                                    .frame(width: 36)  // Fixed width so °C and °F don't shift the layout
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isUnitButtonPressed ? Color.unitButtonPressed : Color.unitButtonBackground)
                                    )
                            }
                            .buttonStyle(PressableButtonStyle(isPressed: $isUnitButtonPressed))
                        }
                    }
                    .padding(.top, 8)
                    
                    // MARK: - Today's Weather (Primary Block)
                    if let today = viewModel.todayWeather {
                        TodayWeatherCard(
                            weather: today,
                            yesterdayWeather: viewModel.yesterdayWeather,
                            city: viewModel.currentCity,
                            unit: viewModel.temperatureUnit,
                            onCityTap: { showCityPicker = true }
                        )
                    } else if viewModel.isLoading {
                        LoadingCard(height: 200)
                    }
                    
                    // MARK: - Yesterday & Tomorrow Row
                    HStack(spacing: 12) {
                        // Yesterday
                        if let yesterday = viewModel.yesterdayWeather {
                            SecondaryWeatherCard(weather: yesterday)
                        } else if viewModel.isLoading {
                            LoadingCard(height: 140)
                        }
                        
                        // Tomorrow
                        if let tomorrow = viewModel.tomorrowWeather {
                            SecondaryWeatherCard(weather: tomorrow)
                        } else if viewModel.isLoading {
                            LoadingCard(height: 140)
                        }
                    }
                    
                    // MARK: - Temp by Hour (3-day) Chart
                    if let yesterday = viewModel.yesterdayWeather,
                       let today = viewModel.todayWeather,
                       let tomorrow = viewModel.tomorrowWeather {
                        ThreeDayHourlyChart(
                            yesterday: yesterday,
                            today: today,
                            tomorrow: tomorrow
                        )
                    }
                    
                    // MARK: - My Cities Section (placeholder for future)
                    if !viewModel.savedCities.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("My Cities")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding(.top, 8)
                            
                            ForEach(viewModel.savedCities) { city in
                                SavedCityCard(city: city)
                                    .onTapGesture {
                                        Task {
                                            await viewModel.selectCity(city)
                                        }
                                    }
                            }
                        }
                    }
                    
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
        }
        .task {
            // Fetch weather when the view appears
            await viewModel.fetchWeather()
        }
        .refreshable {
            // Pull to refresh
            await viewModel.fetchWeather()
        }
        .sheet(isPresented: $showCityPicker) {
            CityPickerSheet(viewModel: viewModel)
        }
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
                .foregroundColor(.secondary)
            
            // Big temperature number
            HStack(alignment: .top, spacing: 2) {
                Text("\(weather.currentTemp ?? weather.highTemp)")
                    .font(.system(size: 80, weight: .regular))
                Text(unit.symbol)
                    .font(.title2)
                    .padding(.top, 12)
            }
            
            // High / Low
            HStack(spacing: 16) {
                Text("\(weather.lowTemp)°")
                    .foregroundColor(.secondary)
                Text("\(weather.highTemp)°")
                    .foregroundColor(.primary)
            }
            .font(.title3)
            
            // Weather condition and comparison
            HStack(spacing: 6) {
                Text(weather.condition.displayName)
                    .foregroundColor(.secondary)
                
                if let comparison = comparisonText {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(comparison)
                        .foregroundColor(.secondary)
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
                        .foregroundColor(.primary)
                    
                    // Dropdown indicator with custom colors
                    Circle()
                        .fill(Color.chevronBackground)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.chevronIcon)
                        )
                }
                .font(.body)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Secondary Weather Card (Yesterday/Tomorrow)

struct SecondaryWeatherCard: View {
    let weather: DayWeather
    
    var body: some View {
        VStack(spacing: 12) {
            // Abbreviated date
            Text(weather.date.abbreviatedDateString)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Weather icon - fixed frame for consistent card heights
            WeatherIcon(condition: weather.condition)
                .frame(width: 40, height: 40)
            
            // Weather condition label
            Text(weather.condition.displayName)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // High / Low
            HStack(spacing: 12) {
                Text("\(weather.lowTemp)°")
                    .foregroundColor(.secondary)
                Text("\(weather.highTemp)°")
                    .fontWeight(.medium)
            }
            .font(.title3)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Weather Icon (supports both SF Symbols and custom PNGs)

struct WeatherIcon: View {
    let condition: WeatherCondition
    var size: CGFloat = 32
    
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
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Saved City Card (for My Cities section)

struct SavedCityCard: View {
    let city: SavedCity
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(city.name)
                    .font(.headline)
                Text("--")  // Placeholder for time, would need timezone data
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("--°")  // Placeholder for temperature
                .font(.largeTitle)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
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
                        .textFieldStyle(.roundedBorder)
                }
                
                // Cities list (filtered by search)
                Section(searchText.isEmpty ? "All Cities" : "Results") {
                    ForEach(filteredCities) { city in
                        Button {
                            Task {
                                await viewModel.selectCity(city)
                                dismiss()
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
                    }
                }
            }
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
    
    /// Get min and max temps for scaling
    private var tempRange: (min: Double, max: Double) {
        let temps = allHourlyTemps.map { $0.temp }
        guard !temps.isEmpty else { return (0, 10) }
        let minTemp = temps.min() ?? 0
        let maxTemp = temps.max() ?? 10
        // Add padding for visual breathing room
        return (minTemp - 2, maxTemp + 2)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Temp by hour (3-day)")
                .font(.callout)
                .fontWeight(.semibold)
                .padding(.top, 8)
            
            VStack(spacing: 8) {
                // Chart
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    ZStack {
                        // Fill area under the line
                        ContinuousTemperatureFillShape(
                            data: allHourlyTemps,
                            tempRange: tempRange,
                            width: width,
                            height: height
                        )
                        .fill(Color.chartFill)
                        
                        // Line stroke
                        ContinuousTemperatureLineShape(
                            data: allHourlyTemps,
                            tempRange: tempRange,
                            width: width,
                            height: height
                        )
                        .stroke(Color.chartStroke, lineWidth: 2)
                        
                        // Dots at 12pm and 6pm for each day
                        ForEach(0..<3, id: \.self) { dayIndex in
                            // 12pm dot
                            if let point = getPointFor(dayIndex: dayIndex, hour: 12, width: width, height: height) {
                                Circle()
                                    .fill(Color.chartStroke)
                                    .frame(width: 8, height: 8)
                                    .position(point)
                            }
                            
                            // 6pm dot
                            if let point = getPointFor(dayIndex: dayIndex, hour: 18, width: width, height: height) {
                                Circle()
                                    .fill(Color.chartStroke)
                                    .frame(width: 8, height: 8)
                                    .position(point)
                            }
                        }
                        
                        // Labels for 12pm and 6pm
                        ForEach(0..<3, id: \.self) { dayIndex in
                            // 12pm label
                            if let point = getPointFor(dayIndex: dayIndex, hour: 12, width: width, height: height) {
                                Text("12")
                                    .font(.caption2)
                                    .foregroundColor(.chartStroke)
                                    .position(x: point.x, y: point.y - 14)
                            }
                            
                            // 6pm label
                            if let point = getPointFor(dayIndex: dayIndex, hour: 18, width: width, height: height) {
                                Text("6")
                                    .font(.caption2)
                                    .foregroundColor(.chartStroke)
                                    .position(x: point.x, y: point.y - 14)
                            }
                        }
                    }
                }
                .frame(height: 100)
                
                // Day labels
                HStack {
                    Text("Yesterday")
                    Spacer()
                    Text("Today")
                    Spacer()
                    Text("Tomorrow")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
        }
    }
    
    /// Get the CGPoint for a specific day and hour
    private func getPointFor(dayIndex: Int, hour: Int, width: CGFloat, height: CGFloat) -> CGPoint? {
        // Find the temperature for this day and hour
        guard let tempData = allHourlyTemps.first(where: { $0.dayIndex == dayIndex && $0.hour == hour }) else {
            return nil
        }
        
        // X position: each day is 24 hours, total 72 hours
        let totalHours: CGFloat = 72
        let hourPosition = CGFloat(dayIndex * 24 + hour)
        let x = (hourPosition / totalHours) * width
        
        // Y position based on temperature
        let tempRangeSpan = tempRange.max - tempRange.min
        let yRatio = tempRangeSpan > 0 ? (tempData.temp - tempRange.min) / tempRangeSpan : 0.5
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
        
        path.move(to: firstPoint)
        for point in points.dropFirst() {
            path.addLine(to: point)
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
        path.move(to: CGPoint(x: firstPoint.x, y: height))
        
        // Go up to first data point
        path.addLine(to: firstPoint)
        
        // Draw line through all points
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        
        // Go down to bottom-right
        path.addLine(to: CGPoint(x: lastPoint.x, y: height))
        
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
