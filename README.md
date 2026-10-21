# Vincenty

Vincenty's direct and inverse solutions of geodesics on an ellipsoid, in Swift with no dependencies. Accurate to within 0.5 mm in distance and 0.000015″ in bearing.

- **Direct**: from a start point, distance and initial bearing, find the destination and final bearing.
- **Inverse**: from two points, find the distance between them and the bearing at each end.

```swift
import Vincenty

let landsEnd = GeodeticCoordinate(latitude: 50.06632, longitude: -5.71475)
let johnOGroats = GeodeticCoordinate(latitude: 58.64402, longitude: -3.07009)

let inverse = try Ellipsoid.wgs84.inverse(from: landsEnd, to: johnOGroats)
// inverse.distance == 969954.166 m, inverse.initialBearing == 9.1418775°

let direct = try Ellipsoid.wgs84.direct(from: landsEnd, distance: 969_954.166, initialBearing: 9.1418775)
// direct.destination ≈ johnOGroats
```

Coordinates and bearings are decimal degrees; distances are metres. There's no default ellipsoid: call the methods on the one you want, usually `Ellipsoid.wgs84`.

## Errors

- `VincentyError.invalidInput`: a coordinate, distance or bearing was NaN or infinite.
- `VincentyError.failedToConverge`: only for nearly antipodal points (e.g. (0°, 0°) to (0.5°, 179.7°)).

Bearings that don't exist are `nil`: the final bearing after travelling zero distance, and both bearings between coincident points.

## Provenance

A port of [`latlon-ellipsoidal-vincenty.js`](https://github.com/chrisveness/geodesy/blob/master/latlon-ellipsoidal-vincenty.js) from Chris Veness's geodesy library, keeping its variable names so the two can be read side by side. The tests are translated from that library's test suite, including Rainsford's cases from Vincenty's paper and Geoscience Australia's Flinders Peak to Buninyong.

T Vincenty, "Direct and Inverse Solutions of Geodesics on the Ellipsoid with application of nested equations", *Survey Review*, vol XXIII no 176, 1975. [inverse.pdf](https://www.ngs.noaa.gov/PUBS_LIB/inverse.pdf)

## Licence

MIT. Includes Chris Veness's MIT notice for the ported code; see [LICENSE](LICENSE).
