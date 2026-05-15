//
//  PhoneAppCGMProviderPickerView.swift
//  LibreWrist
//
//  Created by Peter Müller on 07.05.26.
//
//  First-launch CGM provider picker. Shown by ContentView once when:
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
        VStack(spacing: 0) {
            Text("FLwatch")
                .padding(.top, 40)
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
                    subtitle: "Connects via your LibreLinkUp follower account.",
                    systemImage: "drop.circle"
                ) {
                    pick(.libreLinkUp)
                }

                providerCard(
                    title: "Dexcom",
                    subtitle: "Connects via Dexcom Share. Requires the Share feature to be set up in the Dexcom app.",
                    systemImage: "waveform.path.ecg"
                ) {
                    pick(.dexcomShare)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
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
