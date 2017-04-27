//
//  MKPolyline.swift
//  PARKR
//
//  Created by fnord on 4/27/17.
//  Copyright © 2017 SsosSoft. All rights reserved.
//

import Foundation
import MapKit

// Convenience init for creating Polyline
private extension MKPolyline {
    convenience init(coordinates coords: Array<CLLocationCoordinate2D>) {
        let unsafeCoordinates = UnsafeMutablePointer<CLLocationCoordinate2D>.allocate(capacity: coords.count)
        unsafeCoordinates.initialize(from: coords)
        self.init(coordinates: unsafeCoordinates, count: coords.count)
        unsafeCoordinates.deallocate(capacity: coords.count)
    }
}
