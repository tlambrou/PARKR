//
//  JSONReader.swift
//  JSON-demo
//
//  Created by Nikolas Burk on 30/11/16.
//  Copyright © 2016 Nikolas Burk. All rights reserved.
//

import Foundation


func readJSON(from file: String) {

  let path = Bundle.main.path(forResource: "example", ofType: "json")
  
  let text = try! String(contentsOfFile: path!) // read as string
  let json = try! JSONSerialization.jsonObject(with: text.data(using: .utf8)!, options: []) as? [String: Any]
  print(json)
  
}
