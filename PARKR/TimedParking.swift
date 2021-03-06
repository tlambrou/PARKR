//
//  TimeParking.swift
//  PARKR
//
//  Created by Tassos Lambrou on 11/28/16.
//  Copyright © 2016 SsosSoft. All rights reserved.
//

import Foundation
import SwiftyJSON
import UIKit
import MapKit


class TimedParking {
  var DoW: DayRange?
  var days: String
  var hoursBegin: DateComponents
  var hoursEnd: DateComponents
  var limit: Int {
    didSet {
      hourLimit = TimeInterval(limit * 3600)
    }
  }
  var hourLimit: TimeInterval{
    didSet {
      let newLimit = Int(hourLimit) / 3600
      if limit != newLimit {
        limit = newLimit
      }
    }
  }
  var id: Int
  var midPoint: CLLocation?
  var geometry: [CLLocationCoordinate2D] {
    didSet {
      if self.geometry.count > 1 {
        let secondLat = geometry[1].latitude
        let firstLat = geometry[0].latitude
        let secondLong = geometry[1].longitude
        let firstLong = geometry[0].longitude
        let long = (secondLong - firstLong)/2
        let lat = (secondLat - firstLat)/2
        midPoint = CLLocation(latitude: lat, longitude: long)
      }
    }
  }
  //  var geom: [Coordinates]
  var mapRect: MKMapRect? = nil
  var line: MKPolyline? = nil {
    didSet {
      self.mapRect = self.line!.boundingMapRect
    }
  }
  
  init(json: JSON) {
    
//    print(json)
    let number:Double? = Double(json["properties"]["hours_begin"].intValue) / 100
    let timeBegin = (number!)
    //    print(timeBegin)
    let hourBegin = floor(timeBegin)
    //    print(hourBegin)
    
    var minuteBegin: Int
    if hourBegin == 0 {
      minuteBegin = 0
    } else {
      minuteBegin = Int((timeBegin.truncatingRemainder(dividingBy: hourBegin))*100)
    }

    let number2: Double? = Double(json["properties"]["hours_end"].intValue) / 100
    let timeEnd = number2 ?? 0
    let hourEnd = floor(timeEnd)
    
    var minuteEnd: Int
    if hourEnd == 0 {
      minuteEnd = 0
    } else {
      minuteEnd = Int((timeEnd.truncatingRemainder(dividingBy: hourEnd))*100)
    }
    
    self.days = json["properties"]["days"].stringValue
//    print("Days Value: ", json["properties"]["days"])
    
    switch days {
    case "M-F":
      DoW = .mondayThruFriday
    case "M-Sa":
      DoW = .mondayThruSaturday
    case "M-Su":
      DoW = .mondayThruSunday
    case "M-S":
      DoW = .mondayThruSunday
    case "M_F":
      DoW = .mondayThruFriday
    default:
      DoW = .mondayThruSunday
    }
    
    self.hoursBegin = DateComponents(hour: Int(hourBegin), minute: minuteBegin)
    self.hoursEnd = DateComponents(hour: Int(hourEnd), minute: minuteEnd)
    let limitTemp = json["properties"]["hour_limit"].stringValue
//    print("JSON for HourLimit", json["properties"]["hour_limit"])
    // If hoursLimit is 0 set it to 72 hours
    if limitTemp == "0" || limitTemp == "null" || limitTemp == "" {
      self.limit = 72
    } else {
      if limitTemp != nil {
        self.limit = Int(Double(limitTemp)!)
      } else {
        self.limit = 0
      }
    }
//    print("Here is the final value", self.limit)
    
//    print("\nHour Limit (Primative): ", self.limit)
    self.hourLimit = TimeInterval(self.limit * 3600)
//    print("\nHour Limit (Interval): ", self.hourLimit)
    self.id = Int(json["properties"]["object_id"].stringValue) ?? 999999
    
    print("Hrs Begin \(self.hoursBegin)")
    print("Hrs End \(self.hoursEnd)")
    print("Hrs Limit \(self.hourLimit)")
    //    self.geom = json["geometry"]["coordinates"].arrayValue.map { json in
    //      let coord = Coordinates(json: json)
    //      return coord
    //    }
    
    self.geometry = json["geometry"]["coordinates"].arrayValue.map { json in
      let coord = CLLocationCoordinate2D(latitude:CLLocationDegrees(String(describing: json.arrayValue[1]))!, longitude: CLLocationDegrees(String(describing: json.arrayValue[0]))!)
      return coord
    }
    
    let coordinates: [CLLocationCoordinate2D] = self.geometry.map {
      location in
      return location
    }
    
//        print(coordinates, separator: "\n\n\n", terminator: "\n\n-----------\n")
    
    self.line = MKPolyline(coordinates: coordinates, count: coordinates.count)
    
    self.mapRect = self.line?.boundingMapRect
    
//        print("Number of points", self.line!.pointCount, separator: "\n\n\n", terminator: "\n\n-----------\n\n")
    
    if geometry.count > 1 {
      let secondLat = self.geometry[1].latitude
      let firstLat = self.geometry[0].latitude
      let secondLong = self.geometry[1].longitude
      let firstLong = self.geometry[0].longitude
      let long = (secondLong - firstLong)/2
      let lat = (secondLat - firstLat)/2
      self.midPoint = CLLocation(latitude: lat, longitude: long)
    }
    
    
  }
  
  init(days: String, hoursBegin: DateComponents, hoursEnd: DateComponents, hourLimit: Int, id: Int, geometry: [CLLocationCoordinate2D]) {
    
    self.days = days
    self.hoursBegin = hoursBegin
    self.hoursEnd = hoursEnd
    self.limit = hourLimit
    self.hourLimit = TimeInterval(self.limit * 3600)

    self.id = id
    self.geometry = geometry
    
    let coordinates: [CLLocationCoordinate2D] = self.geometry.map {
      location in
      return location
    }
    
    self.line = MKPolyline(coordinates: coordinates, count: coordinates.count)
    
    self.mapRect = self.line?.boundingMapRect
    
    let secondLat = self.geometry[1].latitude
    let firstLat = self.geometry[0].latitude
    let secondLong = self.geometry[1].longitude
    let firstLong = self.geometry[0].longitude
    let long = (secondLong - firstLong)/2
    let lat = (secondLat - firstLat)/2
    self.midPoint = CLLocation(latitude: lat, longitude: long)
    
  }
  
}
