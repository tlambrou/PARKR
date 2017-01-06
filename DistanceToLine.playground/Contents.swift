//: Playground - noun: a place where people can play

import UIKit
import MapKit
import CoreLocation
  

func distanceCurrentLocToSegment(p: CLLocation, p1: CLLocation, p2: CLLocation) -> Double {
  
  let x1 = p1.coordinate.longitude
  let x2 = p2.coordinate.longitude
  let y1 = p1.coordinate.latitude
  let y2 = p2.coordinate.latitude
  
  var ix: Double = 0
  var iy: Double = 0
  
  // Find magnitude of line segment
  func lineMagnitude (x1: Double, y1: Double, x2: Double, y2: Double) -> Double {
    return sqrt(pow((x2-x1), 2) + pow((y2-y1), 2))
  }
  
  let lineMag = lineMagnitude(x1: x1, y1: y1, x2: x2, y2: y2)
  
  if lineMag < 0.00000001 {
    print("short segment")
    return 9999
  }
  
  let px = p.coordinate.longitude
  let py = p.coordinate.latitude
  
  // Find distance "u"
  var u = (((px - x1) * (x2 - x1)) + ((py - y1) * (y2 - y1)))
  u = u / (lineMag * lineMag)
  
  if ((u < 0.00001) || (u > 1)) {
    ix = lineMagnitude(x1: px, y1: py, x2: x1, y2: y1)
    iy = lineMagnitude(x1: px, y1: py, x2: x2, y2: y2)
    if ix > iy {
      return iy
    } else {
      return ix
    }
  } else {
    ix = x1 + u * (x2 - x1)
    iy = y1 + u * (y2 - y1)
    return lineMagnitude(x1: px, y1: py, x2: ix, y2: iy)
  }
  
}

// Test Case 1

var p = CLLocation(latitude: 5, longitude: 5)
var p1 = CLLocation(latitude: 10, longitude: 10)
var p2 = CLLocation(latitude: 20, longitude: 20)

if (abs(distanceCurrentLocToSegment(p: p , p1: p1, p2: p2)) - 7.0710678118654) > 0.0001 {
  print("Stop - Error 1")
}

// Test Case 2

p = CLLocation(latitude: 15, longitude: 15)
p1 = CLLocation(latitude: 10, longitude: 10)
p2 = CLLocation(latitude: 20, longitude: 20)

if (abs(distanceCurrentLocToSegment(p: p , p1: p1, p2: p2)) - 7.0710678118654) > 0.0001 {
  print("Stop - Error 2")
}

