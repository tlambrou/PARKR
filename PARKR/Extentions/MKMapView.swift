//
//  MKMapView.swift
//  PARKR
//
//  Created by fnord on 4/27/17.
//  Copyright © 2017 SsosSoft. All rights reserved.
//

import Foundation
import MapKit

extension MKMapView {
    func topLeftCoordinate() -> CLLocationCoordinate2D {
        return convert(CGPoint.zero, toCoordinateFrom: self)
    }
    
    func bottomRightCoordinate() -> CLLocationCoordinate2D {
        return convert(CGPoint(x: frame.width, y: frame.height), toCoordinateFrom: self)
    }
}
