//
//  PhoneAppDexcomShareConnectView.swift
//  LibreWrist
//
//  Created by Peter Müller on 07.05.26.
//
//  Dexcom Share account connect screen. Mirrors the LibreLinkUp variant.
//  Region (US vs. Outside US) is auto-detected by DexcomShareProvider on
//  first connect — no picker shown to the user.
//

import SwiftUI

struct PhoneAppDexcomShareConnectView: View {

    @State private var email: String = SharedData.dexcomShareUsername
    @State private var password: String
    @State private var connected: Connection = UserDefaults.group.connected
    @State private var errorMessage: String = "[...]"
    @State private var isShowingConnectionFailed = false

    private let provider = DexcomShareProvider()
    private let timer = Timer.publish(every: 1, tolerance: 0.5, on: .main, in: .common).autoconnect()

    init() {
        let stored = (try? DexcomShareTokenStore.read(.password)) ?? nil ?? ""
        _password = State(initialValue: stored)
    }

    private func statusMessage() -> LocalizedStringResource {
        switch connected {
        case .connected:    return "Connected."
        case .connecting:   return "Connecting..."
        case .disconnected: return "Disconnected"
        case .failed:       return "Connection failed."
        case .locked:       return "Access temporarly locked."
        }
    }

    private func statusColor() -> Color {
        switch connected {
        case .connected:    return .green
        case .connecting:   return .orange
        case .disconnected: return .gray
        case .failed:       return .red
        case .locked:       return .black
        }
    }

    private var resolvedRegionLabel: String {
        guard SharedData.dexcomShareRegionIsKnown else { return "" }
        return SharedData.dexcomShareRegion.displayName
    }

    var body: some View {
        VStack {
            Text("FLwatch")
                .padding(EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0))
                .font(.system(.title))
                .foregroundColor(.green)

            Form {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Use the CGM wearer's own credentials")
                                .font(.headline)

                            Text("Enter the email and password of the **Dexcom account that wears the sensor** — the same login as the Dexcom G7/G6/ONE app on the wearer's phone. FLwatch then acts as a parallel display of that data, the same way xdrip4ios and Loop do.")

                            Text("**Follower / Share-invite accounts will not work.** Dexcom's Share service does not expose follower-mode reading to third-party apps; only the wearer's own account can pull readings.")

                            Text("Share is unofficial. Dexcom may change or restrict it without notice.")
                        }
                        .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }

                Section(
                    header: Text("Credentials"),
                    footer: Text("Region (United States, outside US, or Japan) is detected automatically when you press Connect.\n[TROUBLE? TAP TO OPEN HELP](https://flwatch.app/)")
                ) {
                    TextField(text: $email, prompt: Text("Email address")) {
                        Text("Email")
                    }
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .submitLabel(.done)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .onChange(of: email) {
                        UserDefaults.group.connected = .disconnected
                    }

                    SecureField(text: $password, prompt: Text("Password")) {
                        Text("Password")
                    }
                    .submitLabel(.done)
                    .onChange(of: password) {
                        UserDefaults.group.connected = .disconnected
                    }
                }

                Section {
                    Button("Connect") {
                        tryToConnect()
                    }
                }
                .disabled(email.isBlank || password.isBlank)

                if !resolvedRegionLabel.isEmpty {
                    Section("Region") {
                        LabeledContent("Detected region", value: resolvedRegionLabel)
                            .foregroundStyle(.secondary)
                    }
                }

                if connected == .connected {
                    Text("**Not for treatment decisions.**\n\nThe information presented in this app and its extensions must not be used for treatment or dosing decisions. Consult the glucose-monitoring system and/or a healthcare professional.")
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
            }
            .disabled(connected == .connecting || connected == .locked)

            Text(statusMessage())
                .padding(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                .frame(maxWidth: .infinity)
                .background(statusColor())

            Spacer()
        }
        .alert("Warning", isPresented: $isShowingConnectionFailed) {
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if connected == .connecting {
                ZStack {
                    Color(white: 0, opacity: 0.25)
                        .cornerRadius(10)
                    ProgressView().tint(.white)
                }
            }
        }
        .onReceive(timer) { _ in
            connected = UserDefaults.group.connected
        }
        .task {
            // Pull the latest stored password if the user just changed it elsewhere.
            if let stored = (try? DexcomShareTokenStore.read(.password)) ?? nil {
                password = stored
            }
            email = SharedData.dexcomShareUsername.isEmpty ? email : SharedData.dexcomShareUsername
        }
    }

    private func tryToConnect() {
        // Trim whitespace from both fields. A surprisingly common failure
        // mode: password managers paste a trailing space or newline that the
        // SecureField happily keeps, and Share then reports the password as
        // invalid with no clue why.
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEmail != email { email = trimmedEmail }
        if trimmedPassword != password { password = trimmedPassword }

        UserDefaults.group.connected = .connecting
        Task {
            do {
                try await provider.connect(email: trimmedEmail, password: trimmedPassword)
                UserDefaults.group.connected = .connected
            } catch {
                errorMessage = error.localizedDescription
                isShowingConnectionFailed = true
                // The provider sets `.failed` / `.locked` for terminal auth
                // errors. For everything else (e.g. network), reset to
                // `.disconnected` so the user can retry.
                if UserDefaults.group.connected == .connecting {
                    UserDefaults.group.connected = .disconnected
                }
            }
        }
    }
}

#Preview {
    PhoneAppDexcomShareConnectView()
}
