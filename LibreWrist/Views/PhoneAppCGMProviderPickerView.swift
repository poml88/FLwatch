//
//  PhoneAppCGMProviderPickerView.swift
//  LibreWrist
//
//  Created by Peter Müller on 07.05.26.
//
//  First-launch CGM provider picker. Shown in PhoneAppHomeView once when:
//    - the user has never explicitly chosen a provider, AND
//    - there are no LibreLinkUp credentials carried over from a 2.0.6 install.
//  Existing LibreLinkUp users skip this and silently default to .libreLinkUp.
//

import SwiftUI

struct PhoneAppCGMProviderPickerView: View {

    /// Called once the user picks a provider. Parent (ContentView) uses this
    /// to dismiss the picker.
    let onPicked: (CGMProviderKind) -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Image("FLwatchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.top, 40)

                    Text("FLwatch")
                        .padding(.top, 16)
                        .font(.system(.largeTitle))
                        .foregroundColor(.green)

                    Text("Pick your CGM")
                        .font(.title2)
                        .padding(.top, 24)

                    Text("You can change this later in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Spacer()

                    VStack(spacing: 16) {
                        providerCard(
                            title: "FreeStyle Libre",
                            subtitle: "Connects via your LibreLinkUp follower account. Detailed setup instructions and a video guide are on the app's website.",
                            systemImage: "drop.circle"
                        ) {
                            pick(.libreLinkUp)
                        }

                        providerCard(
                            title: "Dexcom",
                            subtitle: "Connects via Dexcom Share. In the Dexcom app, turn on Share and invite at least one follower. Then sign in here with the sharer's (patient's) account — not a follower's.",
                            systemImage: "waveform.path.ecg"
                        ) {
                            pick(.dexcomShare)
                        }

                        providerCard(
                            title: "FreeStyle Libre 3 (Bluetooth)",
                            subtitle: "Connects directly to a Libre 3 / Libre 3 Plus sensor over Bluetooth — no follower account or cloud needed. You pair by holding your phone to the sensor.",
                            systemImage: "sensor.tag.radiowaves.forward"
                        ) {
                            pick(.libre3BLE)
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
                // Retain the original balanced spacing when all content fits.
                .frame(minHeight: geometry.size.height)
            }
        }
    }

    private func providerCard(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title)
                    .foregroundStyle(.green)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.4))
            )
        }
        .buttonStyle(.plain)
    }

    private func pick(_ kind: CGMProviderKind) {
        SharedData.cgmProviderKind = kind
        // Clear any stale connection state so the user lands cleanly on the
        // matching connect screen.
        UserDefaults.group.connected = .disconnected
        onPicked(kind)
    }
}

#Preview {
    PhoneAppCGMProviderPickerView { _ in }
}
