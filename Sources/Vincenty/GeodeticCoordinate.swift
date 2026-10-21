/// A latitude and longitude on the surface of an ellipsoid, in decimal degrees.
public struct GeodeticCoordinate: Sendable, Equatable, Hashable {
    /// Degrees, positive north.
    public let latitude: Double
    /// Degrees, positive east.
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    var isFinite: Bool { latitude.isFinite && longitude.isFinite }
}

// MARK: - Angle wrapping
// As Veness's Dms.wrap90/180/360: values already in range are returned untouched, so no
// rounding creeps in from the arithmetic.

/// Constrains latitude to −90...90, reflecting over the poles.
func wrap90(_ degrees: Double) -> Double {
    if -90 <= degrees && degrees <= 90 { return degrees }
    return 4 * 90 / 360 * abs(modulo(degrees - 90, 360) - 180) - 90
}

/// Constrains longitude to −180...180.
func wrap180(_ degrees: Double) -> Double {
    if -180 <= degrees && degrees <= 180 { return degrees }
    return modulo(degrees - 180, 360) - 180
}

/// Constrains a bearing to 0..<360.
func wrap360(_ degrees: Double) -> Double {
    if 0 <= degrees && degrees < 360 { return degrees }
    return modulo(degrees, 360)
}

/// Floored modulo, so negative values wrap upwards (JavaScript's `%` is a remainder).
private func modulo(_ x: Double, _ n: Double) -> Double {
    (x.truncatingRemainder(dividingBy: n) + n).truncatingRemainder(dividingBy: n)
}
