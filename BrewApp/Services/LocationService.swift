import CoreLocation
import Observation

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {

    var coordinate: CLLocationCoordinate2D? = nil
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestAuthorization() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func distanceMeters(to coord: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let userCoord = coordinate else { return nil }
        let from = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
        let to   = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        return from.distance(from: to)
    }

    func formattedDistance(to coord: CLLocationCoordinate2D) -> String? {
        guard let meters = distanceMeters(to: coord) else { return nil }
        let miles = meters / 1609.34
        if miles < 0.05 { return "< 0.1 mi" }
        return String(format: "%.1f mi", miles)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        coordinate = locations.last?.coordinate
        manager.stopUpdatingLocation()
    }
}
