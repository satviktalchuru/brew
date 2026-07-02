import Foundation
import MapKit
import CryptoKit

// Free, native alternative to Google Places: MKLocalSearch is part of Apple's
// own MapKit framework — no API key, no billing account, no usage cost or
// quota. This is what powers real coffee shop discovery.
@Observable
final class PlacesService {

    // Searches for coffee shops/cafes near a coordinate (or worldwide by name
    // if no coordinate is available, e.g. location permission denied).
    func searchCoffeeShops(near coordinate: CLLocationCoordinate2D?, query: String = "coffee") async -> [Shop] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.cafe, .bakery])
        if let coordinate {
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 8000,
                longitudinalMeters: 8000
            )
        }

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.compactMap(Self.makeShop)
        } catch {
            return []
        }
    }

    static func makeShop(from item: MKMapItem) -> Shop? {
        guard let name = item.name else { return nil }
        let coord = item.placemark.coordinate
        let address = [item.placemark.thoroughfare, item.placemark.locality]
            .compactMap { $0 }
            .joined(separator: ", ")
        return Shop(
            id: deterministicID(name: name, coordinate: coord),
            name: name,
            address: address.isEmpty ? (item.placemark.title ?? "") : address,
            hours: "",
            distance: "",
            heroSymbol: "cup.and.saucer.fill",
            latitude: coord.latitude,
            longitude: coord.longitude
        )
    }

    // The same real-world place (by name + coordinate rounded to ~11m) always
    // produces the same UUID, so re-discovering it upserts onto one shared
    // row in Supabase instead of creating duplicates.
    static func deterministicID(name: String, coordinate: CLLocationCoordinate2D) -> UUID {
        let key = "\(name.lowercased())|\(String(format: "%.4f", coordinate.latitude))|\(String(format: "%.4f", coordinate.longitude))"
        let digest = SHA256.hash(data: Data(key.utf8))
        let bytes = Array(digest.prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
