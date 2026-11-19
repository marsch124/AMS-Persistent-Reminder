import SwiftUI
import MapKit
import UIKit
import AMSIcons
import ReminderCore

/// "At a place" on the reminder page: start nudging when arriving at, or leaving, a place. 0.5 lane "place" (pick 11).
struct PlaceSection: View {
    @Binding var place: Place?
    @ObservedObject private var watcher = PlaceWatcher.shared
    @State private var finding = false
    @State private var failed = false
    @State private var camera: MapCameraPosition = .automatic

    static let radii: [Double] = [100, 200, 500]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                AppMarkView(.map, size: 14, colour: Theme.blue)
                Text("AT A PLACE").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            }
            .padding(.top, 2)

            Toggle("Start at a place", isOn: Binding(get: { place != nil }, set: { on in
                place = on ? Place(name: "Home", latitude: 0, longitude: 0, radius: 200, onArrive: true) : nil
            }))
            .tint(Theme.blue)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("place-switch")

            if let p = place {
                TextField("Name of the place", text: bind(\.name))
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("place-name")

                Button(action: useHere) {
                    Text(finding ? "Finding where you are…" : "Use where I am now")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(Theme.blueFill, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(finding)
                .accessibilityIdentifier("place-use-here")

                if failed {
                    Text("I could not find where you are. Try again.").font(.footnote).foregroundStyle(.secondary)
                }

                if watcher.isRefused {
                    HStack {
                        Text("Location is off for this app").font(.subheadline)
                        Spacer()
                        Button("Turn on") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                        .buttonStyle(.borderedProminent).tint(Theme.blue).controlSize(.small)
                        .accessibilityIdentifier("place-turn-on")
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("place-location-off")
                }

                if p.hasSpot {
                    Map(position: $camera, interactionModes: []) {
                        MapCircle(center: center(p), radius: p.radius)
                            .foregroundStyle(Theme.blue.opacity(0.22))
                            .stroke(Theme.blue, lineWidth: 2)
                    }
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("place-map")
                    .onChange(of: p.radius) { _, _ in recenter(p) }
                    .onChange(of: p.latitude) { _, _ in recenter(p) }
                    .onAppear { recenter(p) }
                }

                HStack(spacing: 7) {
                    ForEach(Self.radii, id: \.self) { r in
                        let on = p.radius == r
                        Button { place?.radius = r } label: {
                            Text("\(Int(r)) m")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .foregroundStyle(on ? .white : .primary)
                                .background(on ? Theme.blueFill : Color(.secondarySystemGroupedBackground), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                        .accessibilityIdentifier("place-radius-\(Int(r))")
                    }
                    Spacer(minLength: 0)
                }

                Picker("When", selection: bind(\.onArrive)) {
                    Text("When I arrive").tag(true)
                    Text("When I leave").tag(false)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("place-when")

                Text("Your iPhone tells the app when you get there, even while it is closed. It needs location access set to Always.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func bind<V>(_ key: WritableKeyPath<Place, V>) -> Binding<V> {
        Binding(get: { place![keyPath: key] }, set: { place?[keyPath: key] = $0 })
    }

    private func center(_ p: Place) -> CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude) }

    private func recenter(_ p: Place) {
        let span = max(p.radius * 4, 400)
        camera = .region(MKCoordinateRegion(center: center(p), latitudinalMeters: span, longitudinalMeters: span))
    }

    private func useHere() {
        finding = true; failed = false
        PlaceWatcher.shared.whereAmI { c in
            finding = false
            if let c { place?.latitude = c.latitude; place?.longitude = c.longitude } else { failed = true }
        }
    }
}
