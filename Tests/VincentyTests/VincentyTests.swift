import XCTest
@testable import Vincenty

/// Translated from Chris Veness's latlon-ellipsoidal-vincenty test suite, which our
/// implementation is ported from: https://github.com/chrisveness/geodesy
final class VincentyTests: XCTestCase {
    /// Veness rounds distances to 1 mm.
    private let millimetre = 0.0006
    /// Veness compares DMS to 5 decimal places of an arcsecond.
    private let dmsPrecision = 0.000006 / 3600
    /// Veness rounds bearings to 7 decimal places of a degree.
    private let bearingPrecision = 0.00000006

    private let wgs84 = Ellipsoid.wgs84
    private let bessel1841 = Ellipsoid(semiMajorAxis: 6_377_397.155, flattening: 1 / 299.1528128)
    private let international1924 = Ellipsoid(semiMajorAxis: 6_378_388, flattening: 1 / 297)

    private let landsEnd = GeodeticCoordinate(latitude: 50.06632, longitude: -5.71475)
    private let johnOGroats = GeodeticCoordinate(latitude: 58.64402, longitude: -3.07009)

    private func dms(_ degrees: Double, _ minutes: Double = 0, _ seconds: Double = 0) -> Double {
        degrees + minutes / 60 + seconds / 3600
    }

    private func assertCoordinate(
        _ actual: GeodeticCoordinate,
        _ expected: GeodeticCoordinate,
        accuracy: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.latitude, expected.latitude, accuracy: accuracy, "latitude", file: file, line: line)
        XCTAssertEqual(actual.longitude, expected.longitude, accuracy: accuracy, "longitude", file: file, line: line)
    }

    // MARK: - Veness @examples and UK

    func test_inverse_landsEndToJohnOGroats() throws {
        let solution = try wgs84.inverse(from: landsEnd, to: johnOGroats)

        XCTAssertEqual(solution.distance, 969_954.166, accuracy: millimetre)
        XCTAssertEqual(try XCTUnwrap(solution.initialBearing), 9.1418775, accuracy: bearingPrecision)
        XCTAssertEqual(try XCTUnwrap(solution.finalBearing), 11.2972204, accuracy: bearingPrecision)
    }

    func test_direct_landsEndToJohnOGroats() throws {
        let solution = try wgs84.direct(from: landsEnd, distance: 969_954.166, initialBearing: 9.1418775)

        assertCoordinate(solution.destination, johnOGroats, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(solution.finalBearing), 11.2972204, accuracy: bearingPrecision)
    }

    func test_inverse_cambridgeToParis() throws {
        let cambridge = GeodeticCoordinate(latitude: 52.205, longitude: 0.119)
        let paris = GeodeticCoordinate(latitude: 48.857, longitude: 2.351)

        XCTAssertEqual(try wgs84.inverse(from: cambridge, to: paris).distance, 404_607.806, accuracy: millimetre)
    }

    // MARK: - Geoscience Australia

    private let flindersPeak = GeodeticCoordinate(latitude: -37.951033416666666, longitude: 144.42486788888888)
    private let buninyong = GeodeticCoordinate(latitude: -37.65282113888889, longitude: 143.92649552777778)

    func test_inverse_flindersPeakToBuninyong() throws {
        let solution = try wgs84.inverse(from: flindersPeak, to: buninyong)

        XCTAssertEqual(solution.distance, 54_972.271, accuracy: millimetre)
        // Published to 0.01″
        XCTAssertEqual(try XCTUnwrap(solution.initialBearing), dms(306, 52, 5.37), accuracy: 0.005 / 3600)
        XCTAssertEqual(try XCTUnwrap(solution.finalBearing) - 180, dms(127, 10, 25.07), accuracy: 0.005 / 3600)
    }

    func test_direct_flindersPeakToBuninyong() throws {
        let solution = try wgs84.direct(from: flindersPeak, distance: 54_972.271, initialBearing: dms(306, 52, 5.37))

        assertCoordinate(solution.destination, buninyong, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(solution.finalBearing) - 180, dms(127, 10, 25.07), accuracy: 0.005 / 3600)
    }

    // MARK: - Rainsford (from Vincenty's 1975 paper)

    private struct RainsfordCase {
        let name: String
        let ellipsoid: Ellipsoid
        let start: GeodeticCoordinate
        let end: GeodeticCoordinate
        let distance: Double
        let initialBearing: Double
        // What Veness's implementation produces, which differs from Rainsford in the 5th decimal of a second.
        let directDestination: GeodeticCoordinate
        let inverseDistance: Double
        let inverseInitialBearing: Double
        let inverseFinalBearing: Double
    }

    private var rainsfordCases: [RainsfordCase] {
        [
            RainsfordCase(
                name: "a", ellipsoid: bessel1841,
                start: .init(latitude: dms(55, 45), longitude: 0),
                end: .init(latitude: -dms(33, 26), longitude: dms(108, 13)),
                distance: 14_110_526.170, initialBearing: dms(96, 36, 8.79960),
                directDestination: .init(latitude: -dms(33, 26, 0.00001), longitude: dms(108, 13, 0.00001)),
                inverseDistance: 14_110_526.170,
                inverseInitialBearing: dms(96, 36, 8.79948), inverseFinalBearing: dms(137, 52, 22.01448)
            ),
            RainsfordCase(
                name: "b", ellipsoid: international1924,
                start: .init(latitude: dms(37, 19, 54.95367), longitude: 0),
                end: .init(latitude: dms(26, 7, 42.83946), longitude: dms(41, 28, 35.50729)),
                distance: 4_085_966.703, initialBearing: dms(95, 27, 59.63089),
                directDestination: .init(latitude: dms(26, 7, 42.83945), longitude: dms(41, 28, 35.50730)),
                inverseDistance: 4_085_966.703,
                inverseInitialBearing: dms(95, 27, 59.63076), inverseFinalBearing: dms(118, 5, 58.96176)
            ),
            RainsfordCase(
                name: "c", ellipsoid: international1924,
                start: .init(latitude: dms(35, 16, 11.24862), longitude: 0),
                end: .init(latitude: dms(67, 22, 14.77638), longitude: dms(137, 47, 28.31435)),
                distance: 8_084_823.839, initialBearing: dms(15, 44, 23.74850),
                directDestination: .init(latitude: dms(67, 22, 14.77636), longitude: dms(137, 47, 28.31438)),
                inverseDistance: 8_084_823.838,
                inverseInitialBearing: dms(15, 44, 23.74836), inverseFinalBearing: dms(144, 55, 39.92160)
            ),
            RainsfordCase(
                name: "d", ellipsoid: international1924,
                start: .init(latitude: dms(1), longitude: 0),
                end: .init(latitude: -dms(0, 59, 53.83076), longitude: dms(179, 17, 48.02997)),
                distance: 19_960_000.000, initialBearing: dms(89),
                directDestination: .init(latitude: -dms(0, 59, 53.83076), longitude: dms(179, 17, 48.02998)),
                inverseDistance: 19_960_000.000,
                inverseInitialBearing: dms(88, 59, 59.99892), inverseFinalBearing: dms(91, 0, 6.11820)
            ),
            RainsfordCase(
                name: "e", ellipsoid: international1924,
                start: .init(latitude: dms(1), longitude: 0),
                end: .init(latitude: dms(1, 1, 15.18952), longitude: dms(179, 46, 17.84244)),
                distance: 19_780_006.558, initialBearing: dms(4, 59, 59.99995),
                directDestination: .init(latitude: dms(1, 1, 15.18955), longitude: dms(179, 46, 17.84244)),
                inverseDistance: 19_780_006.559,
                inverseInitialBearing: dms(5), inverseFinalBearing: dms(174, 59, 59.88480)
            ),
        ]
    }

    func test_rainsford_direct() throws {
        for c in rainsfordCases {
            let solution = try c.ellipsoid.direct(from: c.start, distance: c.distance, initialBearing: c.initialBearing)
            XCTAssertEqual(solution.destination.latitude, c.directDestination.latitude, accuracy: dmsPrecision, "Rainsford \(c.name) latitude")
            XCTAssertEqual(solution.destination.longitude, c.directDestination.longitude, accuracy: dmsPrecision, "Rainsford \(c.name) longitude")
        }
    }

    func test_rainsford_inverse() throws {
        for c in rainsfordCases {
            let solution = try c.ellipsoid.inverse(from: c.start, to: c.end)
            XCTAssertEqual(solution.distance, c.inverseDistance, accuracy: millimetre, "Rainsford \(c.name) distance")
            // Veness rounds inverse bearings to 7 decimal places of a degree before converting to DMS
            XCTAssertEqual(try XCTUnwrap(solution.initialBearing), c.inverseInitialBearing, accuracy: bearingPrecision, "Rainsford \(c.name) initial bearing")
            XCTAssertEqual(try XCTUnwrap(solution.finalBearing), c.inverseFinalBearing, accuracy: bearingPrecision, "Rainsford \(c.name) final bearing")
        }
    }

    // MARK: - Antipodal and convergence

    /// WGS-84 meridional circumference, from Veness's tests.
    private let meridionalCircumference = 40_007_862.918

    func test_inverse_nearAntipodal_converges() throws {
        let distance = try wgs84.inverse(from: .init(latitude: 0, longitude: 0), to: .init(latitude: 0.5, longitude: 179.5)).distance
        XCTAssertEqual(distance, 19_936_288.579, accuracy: millimetre)
    }

    func test_inverse_antipodal_failsToConverge() {
        let cases: [(GeodeticCoordinate, GeodeticCoordinate)] = [
            (.init(latitude: 0, longitude: 0), .init(latitude: 0.5, longitude: 179.7)),   // λ > π
            (.init(latitude: 5, longitude: 0), .init(latitude: -5.1, longitude: 179.4)),  // iteration limit
        ]
        for (start, end) in cases {
            XCTAssertThrowsError(try wgs84.inverse(from: start, to: end)) { error in
                XCTAssertEqual(error as? VincentyError, .failedToConverge)
            }
        }
    }

    func test_inverse_exactlyAntipodal_isHalfMeridian() throws {
        let equatorial = try wgs84.inverse(from: .init(latitude: 0, longitude: 0), to: .init(latitude: 0, longitude: 180))
        XCTAssertEqual(equatorial.distance, meridionalCircumference / 2, accuracy: millimetre)
        XCTAssertEqual(try XCTUnwrap(equatorial.initialBearing), 0, accuracy: bearingPrecision)

        let meridional = try wgs84.inverse(from: .init(latitude: 90, longitude: 0), to: .init(latitude: -90, longitude: 0))
        XCTAssertEqual(meridional.distance, meridionalCircumference / 2, accuracy: millimetre)
        XCTAssertEqual(try XCTUnwrap(meridional.initialBearing), 0, accuracy: bearingPrecision)
    }

    // MARK: - Small distances and coincident points

    func test_inverse_smallDistances() throws {
        let origin = GeodeticCoordinate(latitude: 0, longitude: 0)
        let expected: [(Double, Double)] = [(1e-5, 1.569), (1e-6, 0.157), (1e-7, 0.016), (1e-8, 0.002), (1e-9, 0.000)]
        for (offset, distance) in expected {
            let solution = try wgs84.inverse(from: origin, to: .init(latitude: offset, longitude: offset))
            XCTAssertEqual(solution.distance, distance, accuracy: millimetre, "\(offset)°")
        }
    }

    func test_inverse_coincident_hasZeroDistanceAndNoBearing() throws {
        let solution = try wgs84.inverse(from: landsEnd, to: landsEnd)

        XCTAssertEqual(solution.distance, 0)
        XCTAssertNil(solution.initialBearing)
        XCTAssertNil(solution.finalBearing)
    }

    func test_inverse_oneDegreeOfEquator() throws {
        let distance = try wgs84.inverse(from: .init(latitude: 0, longitude: 0), to: .init(latitude: 0, longitude: 1)).distance
        XCTAssertEqual(distance, 111_319.491, accuracy: millimetre)
    }

    func test_direct_zeroDistance_returnsStart() throws {
        let solution = try wgs84.direct(from: landsEnd, distance: 0, initialBearing: 0)

        XCTAssertEqual(solution.destination, landsEnd)
        XCTAssertNil(solution.finalBearing)
    }

    // MARK: - Antimeridian and quadrants

    func test_inverse_crossingAntimeridian() throws {
        let distance = try wgs84.inverse(from: .init(latitude: 30, longitude: 120), to: .init(latitude: 30, longitude: -120)).distance
        XCTAssertEqual(distance, 10_825_924.089, accuracy: millimetre)
    }

    func test_direct_crossingAntimeridian_wrapsLongitude() throws {
        let start = GeodeticCoordinate(latitude: 30, longitude: 120)
        let end = GeodeticCoordinate(latitude: 30, longitude: -120)
        let inverse = try wgs84.inverse(from: start, to: end)

        let direct = try wgs84.direct(from: start, distance: inverse.distance, initialBearing: try XCTUnwrap(inverse.initialBearing))

        assertCoordinate(direct.destination, end, accuracy: 0.000001)
    }

    func test_inverse_allQuadrants() throws {
        let pairs: [((Double, Double), (Double, Double))] = [
            ((30, 30), (60, 60)), ((60, 60), (30, 30)), ((30, 60), (60, 30)), ((60, 30), (30, 60)),
            ((30, -30), (60, -60)), ((60, -60), (30, -30)), ((30, -60), (60, -30)), ((60, -30), (30, -60)),
            ((-30, -30), (-60, -60)), ((-60, -60), (-30, -30)), ((-30, -60), (-60, -30)), ((-60, -30), (-30, -60)),
            ((-30, 30), (-60, 60)), ((-60, 60), (-30, 30)), ((-30, 60), (-60, 30)), ((-60, 30), (-30, 60)),
        ]
        for (a, b) in pairs {
            let distance = try wgs84.inverse(from: .init(latitude: a.0, longitude: a.1), to: .init(latitude: b.0, longitude: b.1)).distance
            XCTAssertEqual(distance, 4_015_703.021, accuracy: millimetre, "\(a) → \(b)")
        }
    }

    // MARK: - Round trips

    func test_directThenInverse_roundTrips() throws {
        let start = GeodeticCoordinate(latitude: 1, longitude: 1)
        for (distance, bearing) in [(1.0, 0.0), (1_000.0, 45.0), (25_000.0, 186.0), (5_000_000.0, 300.0)] {
            let direct = try wgs84.direct(from: start, distance: distance, initialBearing: bearing)
            let inverse = try wgs84.inverse(from: start, to: direct.destination)

            XCTAssertEqual(inverse.distance, distance, accuracy: millimetre, "\(distance) m at \(bearing)°")
            XCTAssertEqual(try XCTUnwrap(inverse.initialBearing), bearing, accuracy: bearingPrecision, "\(distance) m at \(bearing)°")
        }
    }

    // MARK: - Invalid input

    func test_nonFiniteInput_throws() {
        let nan = Double.nan
        XCTAssertThrowsError(try wgs84.direct(from: landsEnd, distance: nan, initialBearing: 0)) {
            XCTAssertEqual($0 as? VincentyError, .invalidInput)
        }
        XCTAssertThrowsError(try wgs84.direct(from: landsEnd, distance: 1, initialBearing: nan)) {
            XCTAssertEqual($0 as? VincentyError, .invalidInput)
        }
        XCTAssertThrowsError(try wgs84.inverse(from: .init(latitude: nan, longitude: 0), to: landsEnd)) {
            XCTAssertEqual($0 as? VincentyError, .invalidInput)
        }
    }
}
