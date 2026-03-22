import SwiftUI
import EventKit

// MARK: - Calendar Manager

@MainActor
final class CalendarManager: ObservableObject {
    let eventStore = EKEventStore()

    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var events: [EKEvent] = []
    @Published var calendars: [EKCalendar] = []

    init() {
        updateAuthorizationStatus()
    }

    func updateAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if authorizationStatus == .fullAccess || authorizationStatus == .authorized {
            calendars = eventStore.calendars(for: .event)
        }
    }

    func requestAccess() async {
        if #available(macOS 14.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                authorizationStatus = granted ? .fullAccess : .denied
                if granted {
                    calendars = eventStore.calendars(for: .event)
                }
            } catch {
                authorizationStatus = .denied
            }
        } else {
            let granted = await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
            authorizationStatus = granted ? .authorized : .denied
            if granted {
                calendars = eventStore.calendars(for: .event)
            }
        }
    }

    func fetchEvents(from startDate: Date, to endDate: Date) {
        guard authorizationStatus == .fullAccess || authorizationStatus == .authorized else { return }
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        events = eventStore.events(matching: predicate)
    }

    func createEvent(title: String, startDate: Date, endDate: Date, notes: String?, calendarIdentifier: String? = nil) throws {
        guard authorizationStatus == .fullAccess || authorizationStatus == .authorized else { return }

        let calendar: EKCalendar?
        if let id = calendarIdentifier {
            calendar = eventStore.calendar(withIdentifier: id)
        } else {
            calendar = eventStore.defaultCalendarForNewEvents
        }
        guard let cal = calendar else { return }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        event.calendar = cal

        try eventStore.save(event, span: .thisEvent)
    }

    func syncDeadline(_ deadline: Deadline, incidentTitle: String, calendarIdentifier: String? = nil) {
        guard authorizationStatus == .fullAccess || authorizationStatus == .authorized else { return }

        let calendar: EKCalendar?
        if let id = calendarIdentifier {
            calendar = eventStore.calendar(withIdentifier: id)
        } else {
            calendar = eventStore.defaultCalendarForNewEvents
        }
        guard let cal = calendar else { return }

        let event = EKEvent(eventStore: eventStore)
        event.title = "[\(incidentTitle)] \(deadline.title)"
        event.startDate = deadline.dueDate
        event.endDate = deadline.dueDate.addingTimeInterval(3600)
        event.notes = deadline.notes
        event.calendar = cal

        // Add an alert 1 day before
        event.addAlarm(EKAlarm(relativeOffset: -86400))

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            // Silently fail - could add error reporting
        }
    }
}

// MARK: - Calendar Sidebar View

struct CalendarSidebarView: View {
    @StateObject private var calendarManager = CalendarManager()
    @State private var displayedMonth = Date.now
    @State private var selectedDate: Date?

    private let calendar = Calendar.current
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 8) {
            // Month navigation
            HStack {
                Button { previousMonth() } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption2)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthYearString)
                    .font(.system(size: 11, weight: .semibold))

                Spacer()

                Button { nextMonth() } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date {
                        let isToday = calendar.isDateInToday(date)
                        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false

                        Button {
                            selectedDate = date
                        } label: {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 10))
                                .frame(width: 22, height: 22)
                                .background(
                                    isSelected ? Color.accentColor :
                                    isToday ? Color.accentColor.opacity(0.15) : Color.clear
                                )
                                .foregroundStyle(isSelected ? .white : isToday ? .accentColor : .primary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("")
                            .frame(width: 22, height: 22)
                    }
                }
            }

            // Events for selected date
            if let selected = selectedDate {
                let dayEvents = events(for: selected)
                if !dayEvents.isEmpty {
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(dayEvents, id: \.eventIdentifier) { event in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(cgColor: event.calendar.cgColor))
                                        .frame(width: 6, height: 6)
                                    Text(event.title)
                                        .font(.system(size: 10))
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 60)
                }
            }
        }
        .padding(8)
        .onAppear {
            if calendarManager.authorizationStatus == .fullAccess || calendarManager.authorizationStatus == .authorized {
                loadMonthEvents()
            }
        }
        .onChange(of: displayedMonth) {
            loadMonthEvents()
        }
    }

    // MARK: - Helpers

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var daysInMonth: [Date?] {
        let range = calendar.range(of: .day, in: .month, for: displayedMonth)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))!
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1

        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }

    private func events(for date: Date) -> [EKEvent] {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return calendarManager.events.filter { event in
            event.startDate < end && event.endDate > start
        }
    }

    private func previousMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth)!
    }

    private func nextMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth)!
    }

    private func loadMonthEvents() {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))!
        let end = calendar.date(byAdding: .month, value: 1, to: start)!
        calendarManager.fetchEvents(from: start, to: end)
    }
}

// MARK: - Calendar Settings Section

struct CalendarSettingsSection: View {
    @StateObject private var calendarManager = CalendarManager()
    @AppStorage("calendarSyncEnabled") private var calendarSyncEnabled = false
    @AppStorage("selectedCalendarIdentifier") private var selectedCalendarIdentifier = ""

    var body: some View {
        Section("Calendar Integration") {
            Toggle("Sync deadlines to Calendar", isOn: $calendarSyncEnabled)

            if calendarSyncEnabled {
                switch calendarManager.authorizationStatus {
                case .fullAccess, .authorized:
                    Picker("Calendar", selection: $selectedCalendarIdentifier) {
                        Text("Default Calendar").tag("")
                        ForEach(calendarManager.calendars, id: \.calendarIdentifier) { cal in
                            HStack {
                                Circle()
                                    .fill(Color(cgColor: cal.cgColor))
                                    .frame(width: 8, height: 8)
                                Text(cal.title)
                            }
                            .tag(cal.calendarIdentifier)
                        }
                    }

                case .notDetermined:
                    Button("Grant Calendar Access") {
                        Task { await calendarManager.requestAccess() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                case .denied, .restricted:
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("Calendar access denied. Enable in System Settings > Privacy > Calendars.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                case .writeOnly:
                    Text("Write-only access. Full access needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}
