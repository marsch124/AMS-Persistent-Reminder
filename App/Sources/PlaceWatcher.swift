import Foundation
import CoreLocation
import ReminderCore

/// 0.5 (pick 11): watches the places of the reminders that wait for one. iOS wakes the app on an arrival or a
/// leaving, even when it is closed, so this is made at app start (App.init) and keeps its delegate for good.
@MainActor
final class PlaceWatcher: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = PlaceWatcher()
    /// iOS lets an app watch 20 regions at most.
    static let maxRegions = 20

    @Published private(set) var status: CLAuthorizationStatus
    private let manager = CLLocationManager()
    private var wantsAlways = false
    private var onePlace: ((CLLocationCoordinate2D?) -> Void)?

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    /// He said no (or the iPhone's restrictions did): the section says so and offers to open Settings.
    var isRefused: Bool { status == .denied || status == .restricted }

    /// Keeps the watched regions in step with the list: only reminders still waiting for their place, the first 20.
    func sync(_ reminders: [Reminder]) {
        guard !Store.shared.isTesting, CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        let wanted = reminders.filter { $0.isAtPlaceWaiting && $0.place?.hasSpot == true }.prefix(Self.maxRegions)
        let wantedIDs = Set(wanted.map { $0.id.uuidString })
        for region in manager.monitoredRegions where !wantedIDs.contains(region.identifier) {
            manager.stopMonitoring(for: region)
        }
        for r in wanted {
            guard let p = r.place else { continue }
            let id = r.id.uuidString
            let radius = min(max(p.radius, 100), manager.maximumRegionMonitoringDistance)
            let region = CLCircularRegion(center: CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude), radius: radius, identifier: id)
            region.notifyOnEntry = p.onArrive
            region.notifyOnExit = !p.onArrive
            // Start again only when it is new or changed (same identifier would replace it, so compare first).
            if let old = manager.monitoredRegions.first(where: { $0.identifier == id }) as? CLCircularRegion,
               old.center.latitude == region.center.latitude, old.center.longitude == region.center.longitude,
               old.radius == region.radius, old.notifyOnEntry == region.notifyOnEntry, old.notifyOnExit == region.notifyOnExit { continue }
            manager.startMonitoring(for: region)
        }
    }

    /// A place reminder was saved: ask for When-In-Use, then Always (the iPhone shows the second question later).
    func askForAlways() {
        guard !Store.shared.isTesting else { return }
        wantsAlways = true
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse: manager.requestAlwaysAuthorization(); wantsAlways = false
        default: wantsAlways = false
        }
    }

    /// "Use where I am now": one reading of where he is (asks When-In-Use first). Nil when it did not work.
    func whereAmI(_ done: @escaping (CLLocationCoordinate2D?) -> Void) {
        onePlace = done
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted: finishOne(nil)
        default: manager.requestLocation()
        }
    }

    private func finishOne(_ c: CLLocationCoordinate2D?) {
        let f = onePlace
        onePlace = nil
        f?(c)
    }

    // MARK: CLLocationManagerDelegate (called on the main thread: the manager was made there)

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            status = manager.authorizationStatus
            if onePlace != nil {
                switch status {
                case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
                case .denied, .restricted: finishOne(nil)
                default: break
                }
            }
            if wantsAlways, status == .authorizedWhenInUse { wantsAlways = false; manager.requestAlwaysAuthorization() }
            if status == .authorizedWhenInUse || status == .authorizedAlways { sync(Store.shared.list.reminders) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let c = locations.last?.coordinate
        Task { @MainActor in finishOne(c) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in finishOne(nil) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let id = region.identifier
        Task { @MainActor in if let u = UUID(uuidString: id) { Store.shared.reachedPlace(u) } }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        let id = region.identifier
        Task { @MainActor in if let u = UUID(uuidString: id) { Store.shared.reachedPlace(u) } }
    }
}
