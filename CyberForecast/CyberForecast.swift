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

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let data: WeatherData
    let terminalGreen = Color(red: 0.18, green: 0.95, blue: 0.35)

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
                    Image(data.weatherIconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .colorMultiply(terminalGreen)
                }

                // Dashed divider
                Text("- - - - - - - - -")
                    .font(.custom("VT323-Regular", fixedSize: 12))
                    .foregroundColor(terminalGreen)
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

// MARK: - Entry View

struct CyberForecastEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView(data: entry.weather)
        case .systemMedium:
            SmallWidgetView(data: entry.weather)
        case .systemLarge:
            SmallWidgetView(data: entry.weather)
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
