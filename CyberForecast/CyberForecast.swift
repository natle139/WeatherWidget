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
    // Fallback data structure for compilation and rendering previews
        private static var placeholderWeather: WeatherData {
            WeatherData(
                city: "SYDNEY",
                date: Date(),
                temperature: 24.0,
                asset: .sunny,
                high: 27.0,
                low: 16.0,
                uvIndex: 0.0,
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
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, configuration: configuration, weather: Self.placeholderWeather)
            entries.append(entry)
        }

        return Timeline(entries: entries, policy: .atEnd)
    }

//    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
//        // Generate a list containing the contexts this widget is relevant in.
//    }
}

struct CyberForecastEntryView: View {
    var entry: Provider.Entry
    
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
            
        case .systemSmall:
            // Small widget layout
            VStack(spacing: 4) {
                Text(entry.configuration.favoriteEmoji)
                    .font(.largeTitle)
                Text(entry.date, style: .time)
                    .font(.caption)
            }

        case .systemMedium:
            // Medium widget layout
            HStack(spacing: 16) {
                Text(entry.configuration.favoriteEmoji)
                    .font(.largeTitle)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time:")
                        .font(.headline)
                    Text(entry.date, style: .time)
                        .font(.body)
                }
            }

        case .systemLarge:
            // Large widget layout
            VStack(spacing: 12) {
                Text(entry.configuration.favoriteEmoji)
                    .font(.system(size: 60))
                Text("Time:")
                    .font(.title2)
                Text(entry.date, style: .time)
                    .font(.title)
                Text("Favorite Emoji:")
                    .font(.headline)
                    .padding(.top, 8)
            }

        default:
            // Fallback for any other sizes (e.g. accessory/lock screen)
            Text(entry.configuration.favoriteEmoji)
        }
    }
}

struct CyberForecast: Widget {
    let kind: String = "CyberForecast"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            CyberForecastEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
