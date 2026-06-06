//
//  CyberForecast.swift
//  CyberForecast
//
//  Created by Natalie Le on 7/5/2026.
//

import WidgetKit
import SwiftUI

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let weather: WeatherData
}

struct Provider: AppIntentTimelineProvider {
    private static var placeholderWeather: WeatherData {
        WeatherData(
            city: "SYDNEY",
            date: Date(),
            temperature: 22.0,
            asset: .sunny,
            high: 24.0,
            low: 18.0,
            uvIndex: 6.0,
            humidity: 62.0,
            sunrise: "06:42",
            sunset: "17:03",
            hourly: [
                HourlyForecast(time: "12:00", asset: .sunny),
                HourlyForecast(time: "13:00", asset: .mostlySunny),
                HourlyForecast(time: "14:00", asset: .partlyCloudy),
                HourlyForecast(time: "15:00", asset: .clearNight)
            ],
            daily: [
                DailyForecast(dayName: "WED", high: 25.0, low: 15.0, asset: .rain),
                DailyForecast(dayName: "THU", high: 22.0, low: 13.0, asset: .cloudy)
            ],
            isPlaceholder: true
        )
    }

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), weather: Self.placeholderWeather)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration, weather: Self.placeholderWeather)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let weather = (try? await WeatherService.fetch()) ?? Self.placeholderWeather
        let entry = SimpleEntry(date: Date(), configuration: configuration, weather: weather)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// MARK: - Shared Style Constants
private let terminalGreen = Color(red: 0.318, green: 0.722, blue: 0.357) // #51B85B
private let dimGreen      = Color(red: 0.318, green: 0.722, blue: 0.357).opacity(0.45)

// MARK: - Shared Helpers

private func timeString(from date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm" // time string "11:00"
    return f.string(from: date)
}

private func ordinalDate(_ date: Date, includeDayName: Bool) -> String {
    let f = DateFormatter()
        f.dateFormat = includeDayName ? "EEE d MMM yyyy" : "d MMM yyyy"
        // gives either "Tue 16 Mar 2026" or "16 Mar 2026"
        // inject the ordinal suffix after the day number
        let day = Calendar.current.component(.day, from: date)
        let suffix: String = {
            switch day {
            case 11, 12, 13: return "TH"
            case let d where d % 10 == 1: return "ST"
            case let d where d % 10 == 2: return "ND"
            case let d where d % 10 == 3: return "RD"
            default: return "TH"
            }
        }()
        let base = f.string(from: date).uppercased() // "TUE 16 MAR 2026"
        return base.replacingOccurrences(of: "\(day) ", with: "\(day)\(suffix) ") // e.g. "16TH"
}

// MARK: - Shared Subviews

// Dashed divider
private struct TerminalDivider: View {
    var body: some View {
        Text(String(repeating: "- ", count: 30))
            .font(.custom("VT323-Regular", fixedSize: 11))
            .foregroundColor(dimGreen)
            .lineLimit(1)
    }
}

private struct WeatherIcon: View {
    let asset: RetroWeatherAsset
    let size: CGFloat
    var body: some View {
        Image(asset.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

// Inline hourly strip: 12:00 [icon] 13:00 [icon] (medium and large widgets)
private struct HourlyStrip: View {
    let forecasts: [HourlyForecast]
    let iconSize: CGFloat
    let fontSize: CGFloat
 
    var body: some View {
        HStack(spacing: 4) {
            ForEach(forecasts.prefix(4)) { f in
                Text(f.time)
                    .font(.custom("VT323-Regular", fixedSize: fontSize))
                    .foregroundColor(terminalGreen)
                WeatherIcon(asset: f.asset, size: iconSize)
            }
            Spacer(minLength: 0)
        }
    }
}

// Daily row: WED >> H: L: [icon]
private struct DailyRow: View {
    let forecast: DailyForecast
    let iconSize: CGFloat
    let fontSize: CGFloat
 
    var body: some View {
        HStack(spacing: 4) {
            Text("\(forecast.dayName) >> H: \(Int(forecast.high))°C L: \(Int(forecast.low))°C")
                .font(.custom("VT323-Regular", fixedSize: fontSize))
                .foregroundColor(terminalGreen)
            WeatherIcon(asset: forecast.asset, size: iconSize)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let data: WeatherData
//    let terminalGreen = Color(red: 0.18, green: 0.95, blue: 0.35)
//    REASON: moved to shared constants, changed color to match the one on Figma

    var body: some View {

        return ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // City + Icon
                HStack(alignment: .top) {
                    Text(data.city)
                        .font(.custom("VT323-Regular", fixedSize: 20))
                        .foregroundColor(terminalGreen)
                        .lineLimit(1)
                    Spacer()
//                    Image(data.weatherIconName)
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: 36, height: 36)
//                        .colorMultiply(terminalGreen)
                    WeatherIcon(asset: data.asset, size: 36)
                }

                // Dashed divider
//                Text("- - - - - - - - -")
//                    .font(.custom("VT323-Regular", fixedSize: 12))
//                    .foregroundColor(terminalGreen)
//                    .padding(.vertical, 2)
                TerminalDivider()
                    .padding(.vertical, 2)

                // Temp
                Text("TEMP: \(Int(data.temperature))°C")
                    .font(.custom("VT323-Regular", fixedSize: 18))
                    .foregroundColor(terminalGreen)
                    .padding(.bottom, 2)

                // Condition
                Text("COND: \(data.weatherCondition)")
                    .font(.custom("VT323-Regular", fixedSize: 18))
                    .foregroundColor(terminalGreen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.bottom, 2)

                Spacer()

                // Hi / Lo
                Text("H: \(Int(data.high))°C  L: \(Int(data.low))°C")
                    .font(.custom("VT323-Regular", fixedSize: 16))
                    .foregroundColor(terminalGreen)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(terminalGreen, lineWidth: 2.5)
        )
        .cornerRadius(20)
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let data: WeatherData
     
        private var dateString: String { ordinalDate(data.date, includeDayName: false) }
     
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
     
                    // CITY - DATE - TIME  +  floating icon top-right
                    HStack(alignment: .top) {
                        Text("\(data.city) - \(dateString) - \(timeString(from: data.date))")
                            .font(.custom("VT323-Regular", fixedSize: 17))
                            .foregroundColor(terminalGreen)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer()
                        WeatherIcon(asset: data.asset, size: 48)
                    }
     
                    TerminalDivider()
                        .padding(.vertical, 4)
     
                    // TEMP + COND on one line
                    Text("TEMP: \(Int(data.temperature))°C  COND: \(data.weatherCondition)")
                        .font(.custom("VT323-Regular", fixedSize: 18))
                        .foregroundColor(terminalGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.bottom, 3)
     
                    // H / L
                    Text("H: \(Int(data.high))°C  L: \(Int(data.low))°C")
                        .font(.custom("VT323-Regular", fixedSize: 18))
                        .foregroundColor(terminalGreen)
     
                    Spacer()
     
                    // Hourly forecast
                    HourlyStrip(forecasts: data.hourly, iconSize: 22, fontSize: 17)
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(terminalGreen, lineWidth: 2.5))
            .cornerRadius(20)
        }
}

// MARK: - Large Widget View

struct LargeWidgetView: View {
    let data: WeatherData
    
    private var dateString: String { ordinalDate(data.date, includeDayName: true) }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                
                // Small date line
                Text(dateString)
                    .font(.custom("VT323-Regular", fixedSize: 16))
                    .foregroundColor(terminalGreen)
                    .padding(.bottom, 1)
                
                // Big CITY - TIME  +  large icon top-right
                HStack(alignment: .top) {
                    Text("\(data.city) - \(timeString(from: data.date))")
                        .font(.custom("VT323-Regular", fixedSize: 30))
                        .foregroundColor(terminalGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer()
                    WeatherIcon(asset: data.asset, size: 72)
                }
                
                TerminalDivider()
                    .padding(.vertical, 5)
                
                // Info lines
                Group {
                    Text("TEMP: \(Int(data.temperature))°C")
                    Text("COND: \(data.weatherCondition)")
                    Text("H: \(Int(data.high))°C  L: \(Int(data.low))°C")
                    Text("UV INDEX: \(Int(data.uvIndex))  HUMIDITY: \(Int(data.humidity))%")
                    Text("SUNRISE: \(data.sunrise)  SUNSET: \(data.sunset)")
                }
                .font(.custom("VT323-Regular", fixedSize: 19))
                .foregroundColor(terminalGreen)
                .padding(.bottom, 1)
                
                TerminalDivider()
                    .padding(.vertical, 5)
                
                // Hourly forecast
                HourlyStrip(forecasts: data.hourly, iconSize: 26, fontSize: 18)
                    .padding(.bottom, 4)
                
                // Daily forecast rows: 2
                ForEach(data.daily.prefix(2)) { forecast in
                    DailyRow(forecast: forecast, iconSize: 22, fontSize: 19)
                        .padding(.bottom, 2)
                }
                
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(terminalGreen, lineWidth: 2.5))
        .cornerRadius(20)
    }
}

// MARK: - Entry View

struct CyberForecastEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView(data: entry.weather)
        case .systemMedium:
            MediumWidgetView(data: entry.weather)
        case .systemLarge:
            LargeWidgetView(data: entry.weather)
        default:
            SmallWidgetView(data: entry.weather)
        }
    }
}

// MARK: - Widget

struct CyberForecast: Widget {
    let kind: String = "CyberForecast"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            CyberForecastEntryView(entry: entry)
                .containerBackground(Color.black, for: .widget)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
