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

                    Text("Choose how to connect", comment: "Heading of the first-launch picker where users choose a CGM connection method: direct Bluetooth or a cloud service.")
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
                            title: Text("FreeStyle Libre 3 (Bluetooth)", comment: "Provider picker card title for a direct Bluetooth connection to a FreeStyle Libre 3 or Libre 3 Plus sensor."),
                            subtitle: Text("Connects directly to a Libre 3 or Libre 3 Plus sensor over Bluetooth instead of through the cloud. During workouts in FLwatch on your Apple Watch, the watch can read the sensor directly, so you can leave your iPhone behind.", comment: "Description of the Libre 3 Bluetooth connection method. Apple Watch can also read the sensor directly during a workout started in FLwatch on the watch, without the iPhone nearby."),
                            systemImage: "sensor.tag.radiowaves.forward"
                        ) {
                            pick(.libre3BLE)
                        }

                        providerCard(
                            title: Text("FreeStyle Libre (Cloud)", comment: "Provider picker card title for FreeStyle Libre readings received through the LibreLinkUp cloud service, rather than directly over Bluetooth."),
                            subtitle: Text("Connects through your LibreLinkUp follower account.", comment: "Description of the FreeStyle Libre cloud connection method in the first-launch picker. This option uses a LibreLinkUp follower account."),
                            systemImage: "drop.circle"
                        ) {
                            pick(.libreLinkUp)
                        }

                        providerCard(
                            title: Text("Dexcom (Cloud)", comment: "Provider picker card title for the Dexcom Share cloud service."),
                            subtitle: Text("Connects through Dexcom Share using the patient’s account.", comment: "Description of the Dexcom cloud connection method in the first-launch picker. The account belongs to the sensor wearer, not a follower."),
                            systemImage: "waveform.path.ecg"
                        ) {
                            pick(.dexcomShare)
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
        title: Text,
        subtitle: Text,
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
                    title
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    subtitle
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
