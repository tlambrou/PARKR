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
  let days: String
  let hoursBegin: DateComponents
  let hoursEnd: DateComponents
  let hours: Int
  var midPoint: CLLocation?
  var geom: [Coordinates] {
    didSet {
      if self.geom.count > 1 {
        if let secondLat = geom[1].latitude {
          if let firstLat = geom[0].latitude {
            if let secondLong = geom[1].longitude {
              if let firstLong = geom[0].longitude {
                let long = (secondLong - firstLong)/2
                let lat = (secondLat - firstLat)/2
                midPoint = CLLocation(latitude: lat, longitude: long)
              }
            }
            
          }
        }
      }
      
    }
  }
  
  
  init(json: JSON) {
    
    let number:Double? = Double(json["properties"]["hours_begin"].intValue) / 100
    let timeBegin = (number ?? 0)
    print(timeBegin)
    let hourBegin = floor(timeBegin)
    print(hourBegin)
    
    var minuteBegin: Int
    if hourBegin == 0 {
      minuteBegin = 0
    } else {
      minuteBegin = Int((timeBegin.truncatingRemainder(dividingBy: hourBegin))*100)
    }
    
    //    let string:string = "cheese"
    //    if string.length == 4{
    //      var output
    //      for
    //    }
    
    
    print(minuteBegin)
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
    self.hoursBegin = DateComponents(hour: Int(hourBegin), minute: minuteBegin)
    self.hoursEnd = DateComponents(hour: Int(hourEnd), minute: minuteEnd)
    self.hours = Int(json["properties"]["hour_limit"].stringValue) ?? 0
    self.geom = json["geometry"]["coordinates"].arrayValue.map { json in
      let coord = Coordinates(json: json)
      return coord
    }
    
    if self.geom.count > 1 {
      if let secondLat = self.geom[1].latitude {
        if let firstLat = self.geom[0].latitude {
          if let secondLong = self.geom[1].longitude {
            if let firstLong = self.geom[0].longitude {
              let long = (secondLong - firstLong)/2
              let lat = (secondLat - firstLat)/2
              midPoint = CLLocation(latitude: lat, longitude: long)
            }
          }
          
        }
      }
    }
    
    
    //    print("COORDS")
    //    for i in self.geom {
    //      print(i.latitude)
    //      print(i.longitude)
    //      print("\n\n")
    //    }
    
    //    self.name = json["im:name"]["label"].stringValue
    //    self.rightsOwner = json["rights"]["label"].stringValue
    //    self.price = Double(json["im:price"]["attributes"]["amount"].stringValue) ?? 0
    //    self.link = json["link"][0]["attributes"]["href"].stringValue
    //    self.image = json["im:image"][2]["label"].stringValue
    //    self.releaseDate = json["im:releaseDate"]["attributes"]["label"].stringValue
  }
}
