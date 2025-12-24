import SwiftUI

// MARK: - Custom Colors
extension Color {
    static let unitSelectedText = Color(red: 0x3D/255, green: 0x3F/255, blue: 0xD0/255)  // #3D3FD0
    static let unitSelectedCheck = Color(red: 0x6A/255, green: 0x6C/255, blue: 0xFF/255)  // #6A6CFF
    static let chevronBackground = Color(red: 0xE5/255, green: 0xE5/255, blue: 0xE5/255)  // #E5E5E5
    static let chevronIcon = Color(red: 0x7A/255, green: 0x7A/255, blue: 0x7A/255)        // #7A7A7A
    static let unitButtonBackground = Color(red: 0xE5/255, green: 0xE5/255, blue: 0xE5/255)  // #E5E5E5
    static let unitButtonPressed = Color(red: 0xD2/255, green: 0xD2/255, blue: 0xD2/255)     // #D2D2D2
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
                        // Centered title
                        Text("big numba weatha")
                            .font(.title2)
                            .fontWeight(.medium)
                        
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
    let city: SavedCity
    let unit: TemperatureUnit
    let onCityTap: () -> Void
    
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

// MARK: - Preview

#Preview {
    HomeScreen()
}
