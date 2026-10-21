/// A reference ellipsoid, defined by its semi-major axis and flattening.
public struct Ellipsoid: Sendable, Equatable {
    /// Semi-major (equatorial) axis, metres.
    public let a: Double
    /// Flattening, (a − b) / a.
    public let f: Double
    /// Semi-minor (polar) axis, metres.
    public var b: Double { a * (1 - f) }

    public init(semiMajorAxis: Double, flattening: Double) {
        self.a = semiMajorAxis
        self.f = flattening
    }

    public static let wgs84 = Ellipsoid(semiMajorAxis: 6_378_137, flattening: 1 / 298.257223563)
}
