import MRRClockCore
import ServiceManagement
import SwiftUI

@MainActor enum StoredSettings {
    static let defaults = UserDefaults.standard
    static var config: Config {
        var config = Config.default
        if defaults.object(forKey: "earningsStartDate") != nil { config.earningsStartDate = Date(timeIntervalSince1970: defaults.double(forKey: "earningsStartDate")) }
        if defaults.object(forKey: "monthlyGrowthRate") != nil { config.monthlyGrowthRate = Decimal(defaults.double(forKey: "monthlyGrowthRate")) / 100 }
        if defaults.object(forKey: "refreshInterval") != nil { config.refreshInterval = defaults.double(forKey: "refreshInterval") }
        if let raw = defaults.string(forKey: "titleFormat"), let format = TitleFormat(rawValue: raw) { config.titleFormat = format }
        config.includeTrials = defaults.bool(forKey: "includeTrials")
        return config
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var savedKey: String?
    @State private var verification: KeyVerification?
    @State private var verifying = false
    @AppStorage("earningsStartDate") private var earningsStartDate = Config.default.earningsStartDate.timeIntervalSince1970
    @AppStorage("monthlyGrowthRate") private var growth = 0.0
    @AppStorage("refreshInterval") private var refreshInterval = 900.0
    @AppStorage("titleFormat") private var titleFormat = TitleFormat.daysAndMRR.rawValue
    @AppStorage("includeTrials") private var includeTrials = false
    @State private var launchAtLogin = false
    private let keyStore: any KeyStore
    private let intervalChanged: (TimeInterval) -> Void

    init(keyStore: any KeyStore = KeychainKeyStore(), intervalChanged: @escaping (TimeInterval) -> Void = { _ in }) {
        self.keyStore = keyStore
        self.intervalChanged = intervalChanged
    }

    var body: some View {
        Form {
            Section("Stripe key") {
                if let savedKey {
                    Label(KeyVerifier.displayString(for: savedKey), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    HStack { Button("Replace") { self.savedKey = nil }; Button("Remove", role: .destructive) { try? keyStore.delete(); self.savedKey = nil } }
                } else {
                    SecureField("rk_live_…", text: $key)
                    Button(verifying ? "Verifying…" : "Save") { verify() }.disabled(verifying)
                    if case let .rejected(message) = verification { Text(message).foregroundStyle(.red) }
                }
            }
            DatePicker("Earnings start date", selection: Binding(get: { Date(timeIntervalSince1970: earningsStartDate) }, set: { earningsStartDate = $0.timeIntervalSince1970 }), displayedComponents: .date)
                .accessibilityIdentifier("mrrclock.settings-earnings-start")
            Stepper("Monthly growth assumption: \(growth, specifier: "%.0f")%", value: $growth, in: -100...100, step: 1)
            Picker("Refresh interval", selection: $refreshInterval) { Text("5 minutes").tag(300.0); Text("15 minutes").tag(900.0); Text("30 minutes").tag(1800.0); Text("1 hour").tag(3600.0) }
                .onChange(of: refreshInterval) { _, value in intervalChanged(value) }
            Picker("Menu bar title", selection: $titleFormat) {
                Text("387d · $4.2k MRR").tag(TitleFormat.daysAndMRR.rawValue)
                Text("387d").tag(TitleFormat.daysOnly.rawValue)
                Text("$4.2k MRR").tag(TitleFormat.mrrOnly.rawValue)
                Text("62% · 387d").tag(TitleFormat.percentAndDays.rawValue)
            }
            Toggle("Include trials", isOn: $includeTrials)
                .accessibilityIdentifier("mrrclock.settings-include-trials")
            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin },
                set: { enabled in updateLaunchAtLogin(enabled) }
            ))
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Text("Settings").font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .formStyle(.grouped).frame(width: 460, height: 520)
        .task {
            savedKey = try? keyStore.read()
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func verify() {
        verifying = true
        Task {
            let result = await KeyVerifier().verify(key, api: LiveStripeClient(key: key, transport: URLSessionTransport()), keyStore: keyStore)
            await MainActor.run { verification = result; verifying = false; if result == .verified { savedKey = key; key = "" } }
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {}
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
