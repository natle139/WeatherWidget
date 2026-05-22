import Foundation
import CoreLocation

// OpenWeather asset mapping
enum RetroWeatherAsset: String {
    case sunny = "weather_sunny"
    case mostlySunny = "weather_mostly_sunny"
    case partlyCloudy = "weather_partly_cloudy"
    case cloudy = "weather_cloudy"
    case mostlyCloudy = "weather_mostly_cloudy"
    case rain = "weather_rain"
    case heavyRain = "weather_heavy_rain"
    case thunderstorm = "weather_thunderstorm"
    case sleet = "weather_sleet"
    case snow = "weather_snow"
    case heavySnow = "weather_heavy_snow"
    case foggy = "weather_foggy"
    case clearNight = "weather_clear_night"
    
    var labelText: String {
        switch self {
        case .clearNight: return "CLEAR NIGHT"
        default: return self.rawValue.replacingOccurrences(of: "weather_", with: "").replacingOccurrences(of: "_", with: " ").uppercased()
        }
    }
    
    static func from(openWeatherId id: Int, iconCode: String) -> RetroWeatherAsset {
        let isNight = iconCode.contains("n")
        if isNight && id == 800 { return .clearNight }
        
        switch id {
        case 800: return .sunny
        case 801: return .mostlySunny
        case 802: return .partlyCloudy
        case 803: return .cloudy
        case 804: return .mostlyCloudy
        case 200...299: return .thunderstorm
        case 300...321, 500, 520: return .rain
        case 501...504, 521...531: return .heavyRain
        case 511, 611...616: return .sleet
        case 600, 620: return .snow
        case 601, 602, 621, 622: return .heavySnow
        case 701...762: return .foggy
        default: return .sunny
        }
    }
}

struct WeatherData {
    let city: String
    let date: Date
    let temperature: Double
    let asset: RetroWeatherAsset
    
    let high: Double
    let low: Double
    let uvIndex: Double
    let humidity: Double
    let sunrise: String
    let sunset: String
    
    let hourly: [HourlyForecast]
    let daily: [DailyForecast]
    let isPlaceholder: Bool
    
    var weatherCondition: String { asset.labelText }
    var weatherIconName: String { asset.rawValue }
}

struct HourlyForecast: Identifiable {
    let id = UUID()
    let time: String
    let asset: RetroWeatherAsset
}

struct DailyForecast: Identifiable {
    let id = UUID()
    let dayName: String
    let high: Double
    let low: Double
    let asset: RetroWeatherAsset
}

// Importing OpenWeather API
struct WeatherService {
    private static let apiKey = "9dc8d0f09906d8e4d388861066288a8c"
    
    static func fetch(lat: Double = -33.8688, lon: Double = 151.2093) async throws -> WeatherData {
        let currentUrlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&units=metric&appid=\(apiKey)"
        let forecastUrlString = "https://api.openweathermap.org/data/2.5/forecast?lat=\(lat)&lon=\(lon)&units=metric&appid=\(apiKey)"
        
        guard let currentUrl = URL(string: currentUrlString), let forecastUrl = URL(string: forecastUrlString) else {
            throw URLError(.badURL)
        }
        
        async let (currentRawData, _) = URLSession.shared.data(from: currentUrl)
        async let (forecastRawData, _) = URLSession.shared.data(from: forecastUrl)
        
        let currentJSON = try await JSONDecoder().decode(OWMCurrentResponse.self, from: currentRawData)
        let forecastJSON = try await JSONDecoder().decode(OWMForecastResponse.self, from: forecastRawData)
        
        // Sun Timestamps
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let sunriseStr = timeFormatter.string(from: Date(timeIntervalSince1970: currentJSON.sys.sunrise))
        let sunsetStr = timeFormatter.string(from: Date(timeIntervalSince1970: currentJSON.sys.sunset))
        
        // Hourly forecasts (next 4 hours)
        let parsedHourly = forecastJSON.list.prefix(4).map { item -> HourlyForecast in
            let hourStr = timeFormatter.string(from: Date(timeIntervalSince1970: item.dt))
            let weatherItem = item.weather.first
            let mappedAsset = RetroWeatherAsset.from(openWeatherId: weatherItem?.id ?? 800, iconCode: weatherItem?.icon ?? "01d")
            return HourlyForecast(time: hourStr, asset: mappedAsset)
        }
        
        // Daily forecasts (next 2 days)
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE" // yields "WED", "THU"
        
        var uniqueDays: [DailyForecast] = []
        var processedDays: Set<String> = []
        
        for item in forecastJSON.list {
            let itemDate = Date(timeIntervalSince1970: item.dt)
            let currentDayName = dayFormatter.string(from: itemDate).uppercased()
            let todayName = dayFormatter.string(from: Date()).uppercased()
            
            if currentDayName != todayName && !processedDays.contains(currentDayName) {
                processedDays.insert(currentDayName)
                let weatherItem = item.weather.first
                let mappedAsset = RetroWeatherAsset.from(openWeatherId: weatherItem?.id ?? 800, iconCode: weatherItem?.icon ?? "01d")
                
                uniqueDays.append(DailyForecast(
                    dayName: currentDayName,
                    high: item.main.temp_max,
                    low: item.main.temp_min,
                    asset: mappedAsset
                ))
            }
            if uniqueDays.count >= 2 { break }
        }
        
        let primaryWeather = currentJSON.weather.first
        let primaryAsset = RetroWeatherAsset.from(openWeatherId: primaryWeather?.id ?? 800, iconCode: primaryWeather?.icon ?? "01d")
        
        return WeatherData(
            city: currentJSON.name.uppercased(),
            date: Date(timeIntervalSince1970: currentJSON.dt),
            temperature: currentJSON.main.temp,
            asset: primaryAsset,
            high: currentJSON.main.temp_max,
            low: currentJSON.main.temp_min,
            uvIndex: { // openweather doesn't supply UV index metric for free
                let now = Date()
                let calendar = Calendar.current
                
                // Only calculate UV exposure during daylight hours
                if now >= Date(timeIntervalSince1970: currentJSON.sys.sunrise) &&
                   now <= Date(timeIntervalSince1970: currentJSON.sys.sunset) {
                    
                    let hour = calendar.component(.hour, from: now)
                    // Peak solar intensity occurs around solar noon (12:00 - 13:00)
                    let hoursFromNoon = abs(Double(hour - 12))
                    
                    // Base clear-sky maximum value
                    var estimatedUV = max(0.0, 11.0 - (hoursFromNoon * 2.0))
                    
                    // Scale down the exposure if clouds are present
                    let cloudCode = currentJSON.weather.first?.id ?? 800
                    if cloudCode == 804 {        // Overcast
                        estimatedUV *= 0.3
                    } else if cloudCode >= 801 { // Partially Cloudy
                        estimatedUV *= 0.7
                    }
                    
                    return estimatedUV
                } else {
                    return 0.0 // Night time yields zero UV exposure
                }
            }(),
            humidity: Double(currentJSON.main.humidity),
            sunrise: sunriseStr,
            sunset: sunsetStr,
            hourly: Array(parsedHourly),
            daily: uniqueDays,
            isPlaceholder: false
        )
    }
}

// API Request DTO Decodables

private struct OWMCurrentResponse: Decodable {
    let name: String
    let dt: TimeInterval
    let main: MainPayload
    let weather: [WeatherPayload]
    let sys: SysPayload
}

private struct OWMForecastResponse: Decodable {
    let list: [ForecastItem]
}

private struct ForecastItem: Decodable {
    let dt: TimeInterval
    let main: MainPayload
    let weather: [WeatherPayload]
}

private struct MainPayload: Decodable {
    let temp: Double
    let temp_min: Double
    let temp_max: Double
    let humidity: Int
}

private struct WeatherPayload: Decodable {
    let id: Int
    let icon: String
}

private struct SysPayload: Decodable {
    let sunrise: TimeInterval
    let sunset: TimeInterval
}
