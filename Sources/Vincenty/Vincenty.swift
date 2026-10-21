import Foundation

// Vincenty direct and inverse solutions of geodesics on the ellipsoid.
//
// Ported from Chris Veness's latlon-ellipsoidal-vincenty.js (MIT), keeping its variable
// names so the two read side by side: https://github.com/chrisveness/geodesy
//
// T Vincenty, "Direct and Inverse Solutions of Geodesics on the Ellipsoid with application
// of nested equations", Survey Review, vol XXIII no 176, 1975.
// www.ngs.noaa.gov/PUBS_LIB/inverse.pdf

public enum VincentyError: Error, Sendable, Equatable {
    /// A coordinate, distance or bearing was NaN or infinite.
    case invalidInput
    /// The iteration didn't converge, which only happens for nearly antipodal points.
    case failedToConverge
}

public struct DirectSolution: Sendable, Equatable {
    public let destination: GeodeticCoordinate
    /// Bearing on arrival, degrees 0..<360; nil for zero distance.
    public let finalBearing: Double?
}

public struct InverseSolution: Sendable, Equatable {
    /// Length of the geodesic, metres.
    public let distance: Double
    /// Bearing on departure, degrees 0..<360; nil for coincident points.
    public let initialBearing: Double?
    /// Bearing on arrival, degrees 0..<360; nil for coincident points.
    public let finalBearing: Double?
}

public extension Ellipsoid {
    /// The point reached by travelling `distance` metres along a geodesic from `start`,
    /// setting off on `initialBearing` degrees from north.
    func direct(from start: GeodeticCoordinate, distance: Double, initialBearing: Double) throws -> DirectSolution {
        guard start.isFinite, distance.isFinite, initialBearing.isFinite else { throw VincentyError.invalidInput }
        if distance == 0 { return DirectSolution(destination: start, finalBearing: nil) }

        let φ1 = radians(start.latitude), λ1 = radians(start.longitude)
        let α1 = radians(initialBearing)
        let s = distance

        let sinα1 = sin(α1)
        let cosα1 = cos(α1)

        let tanU1 = (1 - f) * tan(φ1), cosU1 = 1 / sqrt(1 + tanU1 * tanU1), sinU1 = tanU1 * cosU1
        let σ1 = atan2(tanU1, cosα1) // σ1 = angular distance on the sphere from the equator to P1
        let sinα = cosU1 * sinα1     // α = azimuth of the geodesic at the equator
        let cosSqα = 1 - sinα * sinα
        let uSq = cosSqα * (a * a - b * b) / (b * b)
        let A = 1 + uSq / 16384 * (4096 + uSq * (-768 + uSq * (320 - 175 * uSq)))
        let B = uSq / 1024 * (256 + uSq * (-128 + uSq * (74 - 47 * uSq)))

        var σ = s / (b * A), sinσ = 0.0, cosσ = 0.0 // σ = angular distance P₁ P₂ on the sphere
        var cos2σₘ = 0.0 // σₘ = angular distance on the sphere from the equator to the midpoint of the line

        var iterations = 0
        while true {
            cos2σₘ = cos(2 * σ1 + σ)
            sinσ = sin(σ)
            cosσ = cos(σ)
            let Δσ = B * sinσ * (cos2σₘ + B / 4 * (cosσ * (-1 + 2 * cos2σₘ * cos2σₘ) - B / 6 * cos2σₘ * (-3 + 4 * sinσ * sinσ) * (-3 + 4 * cos2σₘ * cos2σₘ)))
            let σʹ = σ
            σ = s / (b * A) + Δσ
            if abs(σ - σʹ) <= 1e-12 { break } // TV: 'iterate until negligible change in λ' (≈0.006mm)
            iterations += 1
            if iterations >= 100 { throw VincentyError.failedToConverge }
        }

        let x = sinU1 * sinσ - cosU1 * cosσ * cosα1
        let φ2 = atan2(sinU1 * cosσ + cosU1 * sinσ * cosα1, (1 - f) * sqrt(sinα * sinα + x * x))
        let λ = atan2(sinσ * sinα1, cosU1 * cosσ - sinU1 * sinσ * cosα1)
        let C = f / 16 * cosSqα * (4 + f * (4 - 3 * cosSqα))
        let L = λ - (1 - C) * f * sinα * (σ + C * sinσ * (cos2σₘ + C * cosσ * (-1 + 2 * cos2σₘ * cos2σₘ)))
        let λ2 = λ1 + L

        let α2 = atan2(sinα, -x)

        return DirectSolution(
            destination: GeodeticCoordinate(latitude: wrap90(degrees(φ2)), longitude: wrap180(degrees(λ2))),
            finalBearing: wrap360(degrees(α2))
        )
    }

    /// The geodesic between two points: its length and the bearings at each end.
    func inverse(from start: GeodeticCoordinate, to end: GeodeticCoordinate) throws -> InverseSolution {
        guard start.isFinite, end.isFinite else { throw VincentyError.invalidInput }

        let φ1 = radians(start.latitude), λ1 = radians(start.longitude)
        let φ2 = radians(end.latitude), λ2 = radians(end.longitude)

        let L = λ2 - λ1 // L = difference in longitude, U = reduced latitude, defined by tan U = (1-f)·tanφ.
        let tanU1 = (1 - f) * tan(φ1), cosU1 = 1 / sqrt(1 + tanU1 * tanU1), sinU1 = tanU1 * cosU1
        let tanU2 = (1 - f) * tan(φ2), cosU2 = 1 / sqrt(1 + tanU2 * tanU2), sinU2 = tanU2 * cosU2

        let antipodal = abs(L) > .pi / 2 || abs(φ2 - φ1) > .pi / 2

        var λ = L, sinλ = 0.0, cosλ = 0.0 // λ = difference in longitude on an auxiliary sphere
        var σ = antipodal ? Double.pi : 0, sinσ = 0.0, cosσ = antipodal ? -1.0 : 1.0, sinSqσ = 0.0 // σ = angular distance P₁ P₂ on the sphere
        var cos2σₘ = 1.0 // σₘ = angular distance on the sphere from the equator to the midpoint of the line
        var cosSqα = 1.0 // α = azimuth of the geodesic at the equator

        var iterations = 0
        while true {
            sinλ = sin(λ)
            cosλ = cos(λ)
            sinSqσ = pow(cosU2 * sinλ, 2) + pow(cosU1 * sinU2 - sinU1 * cosU2 * cosλ, 2)
            if abs(sinSqσ) < 1e-24 { break } // co-incident/antipodal points (σ < ≈0.006mm)
            sinσ = sqrt(sinSqσ)
            cosσ = sinU1 * sinU2 + cosU1 * cosU2 * cosλ
            σ = atan2(sinσ, cosσ)
            let sinα = cosU1 * cosU2 * sinλ / sinσ
            cosSqα = 1 - sinα * sinα
            cos2σₘ = (cosSqα != 0) ? (cosσ - 2 * sinU1 * sinU2 / cosSqα) : 0 // on equatorial line cos²α = 0 (§6)
            let C = f / 16 * cosSqα * (4 + f * (4 - 3 * cosSqα))
            let λʹ = λ
            λ = L + (1 - C) * f * sinα * (σ + C * sinσ * (cos2σₘ + C * cosσ * (-1 + 2 * cos2σₘ * cos2σₘ)))
            let iterationCheck = antipodal ? abs(λ) - .pi : abs(λ)
            if iterationCheck > .pi { throw VincentyError.failedToConverge } // λ > π
            if abs(λ - λʹ) <= 1e-12 { break } // TV: 'iterate until negligible change in λ' (≈0.006mm)
            iterations += 1
            if iterations >= 1000 { throw VincentyError.failedToConverge }
        }

        let uSq = cosSqα * (a * a - b * b) / (b * b)
        let A = 1 + uSq / 16384 * (4096 + uSq * (-768 + uSq * (320 - 175 * uSq)))
        let B = uSq / 1024 * (256 + uSq * (-128 + uSq * (74 - 47 * uSq)))
        let Δσ = B * sinσ * (cos2σₘ + B / 4 * (cosσ * (-1 + 2 * cos2σₘ * cos2σₘ) - B / 6 * cos2σₘ * (-3 + 4 * sinσ * sinσ) * (-3 + 4 * cos2σₘ * cos2σₘ)))

        let s = b * A * (σ - Δσ) // s = length of the geodesic

        // note special handling of exactly antipodal points where sin²σ = 0 (due to discontinuity
        // atan2(0, 0) = 0 but atan2(ε, 0) = π/2 / 90°) - in which case bearing is always meridional,
        // due north (or due south!)
        // α = azimuths of the geodesic; α2 the direction P₁ P₂ produced
        let α1 = abs(sinSqσ) < .ulpOfOne ? 0 : atan2(cosU2 * sinλ, cosU1 * sinU2 - sinU1 * cosU2 * cosλ)
        let α2 = abs(sinSqσ) < .ulpOfOne ? .pi : atan2(cosU1 * sinλ, -sinU1 * cosU2 + cosU1 * sinU2 * cosλ)

        let coincident = abs(s) < .ulpOfOne
        return InverseSolution(
            distance: s,
            initialBearing: coincident ? nil : wrap360(degrees(α1)),
            finalBearing: coincident ? nil : wrap360(degrees(α2))
        )
    }
}

private func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
private func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
