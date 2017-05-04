//
//  ParkrAPIWrapper.swift
//  PARKR
//
//  Created by fnord on 4/27/17.
//  Copyright © 2017 SsosSoft. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON
import MapKit

class ParkrAPIWrapper {
    static func getSubset(UCoords: CGPoint, LCoords: CGPoint, callback: @escaping ([TimedParking]) -> ()) {
        Alamofire.request("http://0.0.0.0:8888/api/v1/parking/subset?ULat=\(UCoords.x)&ULong=\(UCoords.y)&LLat=\(LCoords.x)&LLong=\(LCoords.y)").responseJSON(completionHandler: { (response) in
            print(response)
            let rulesJSON = JSON(response.result.value!).array
            let calendar = NSCalendar.current
            
            var timedParkings = [TimedParking]()
            
            for rule in rulesJSON! {
                let timeBegin = calendar.dateComponents(in: calendar.timeZone, from: Date(timeIntervalSince1970: rule["hours_begin"].double!))
                let timeEnd = calendar.dateComponents(in: calendar.timeZone, from: Date(timeIntervalSince1970: rule["hours_end"].double!))
                
                var ruleLine = [CLLocationCoordinate2D]()
                
                for point in rule["rule_line"].array! {
                    ruleLine.append(CLLocationCoordinate2D(latitude: point[0].double!, longitude: point[1].double!))
                }
                
                timedParkings.append(TimedParking(days: "\(rule["day_json"][0].string)-\(rule["day_json"][1].string)", hoursBegin: timeBegin, hoursEnd: timeEnd, hourLimit: rule["hourLimit"].int!, id: 0, geometry: ruleLine))
            }
            
            callback(timedParkings)
        })
    }
}
