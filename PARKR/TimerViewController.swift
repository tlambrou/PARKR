//
//  TimerViewController.swift
//  PARKR
//
//  Created by Buka Cakrawala on 1/11/17.
//  Copyright © 2017 SsosSoft. All rights reserved.
//

import UIKit
import UserNotifications

class TimerViewController: UIViewController {
  
  var viewControllerInstance: MapViewController!
  
  var timer = Timer()
  var counter = 0
  
  @IBOutlet weak var tenMinuteSwitch: UISwitch!
  @IBOutlet weak var fifteenMinuteSwitch: UISwitch!
  @IBOutlet weak var thirtyMinuteSwitch: UISwitch!
  
  @IBOutlet weak var hoursLabel: UILabel!
  @IBOutlet weak var minutesLabel: UILabel!
  @IBOutlet weak var secondsLabel: UILabel!
  @IBOutlet weak var moveByTimeLabel: UILabel!
  
  @IBAction func tenMinuteAction(_ sender: UISwitch) {
    if sender.isOn {
      tenMinuteSwitch.setOn(true, animated: true)
      scheduleNotification(timeInterval: 6600, completion: { (success) in
        if success {
          print("successfully scheduled notification")
        } else {
          print("Error scheduling notification")
        }
      })
    }
  }
  
  @IBAction func fifteenMinuteAction(_ sender: UISwitch) {
    if sender.isOn {
      fifteenMinuteSwitch.setOn(true, animated: true)
      scheduleNotification(timeInterval: 6300, completion: { (success) in
        if success {
          print("successfully scheduled notification")
        } else {
          print("Error scheduling notification")
        }
      })
    }
  }
  @IBAction func thirtyMinuteAction(_ sender: UISwitch) {
    if sender.isOn {
      thirtyMinuteSwitch.setOn(true, animated: true)
      
      scheduleNotification(timeInterval: 4, completion: { (success) in
        if success {
          print("successfully scheduled notification")
        } else {
          print("Error scheduling notification")
        }
      })
    }
  }
  
  func updateTimer () {
    counter -= 1
    let hours = Int(counter) / 3600
    let minutes = Int(counter) / 60 % 60
    let seconds = Int(counter) % 60
    hoursLabel.text = String(format: "%02i",hours)
    minutesLabel.text = String(format: "%02i",minutes)
    secondsLabel.text = String(format: "%02i",seconds)
  }
  @IBAction func stopAction(_ sender: UIButton) {
    // TODO: Stop the timer
    timer.invalidate()
    
    self.dismiss(animated: true, completion: nil)
  }
  override func viewDidLoad() {
    super.viewDidLoad()
    
    moveByTimeLabel.text = viewControllerInstance.activeParking?.moveByText
    
    counter = (Int((viewControllerInstance.activeParking?.moveByTime?.timeIntervalSince(Date()))!))
    
    timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
    
    self.configureNotification()
    
    tenMinuteSwitch.setOn(false, animated: true)
    fifteenMinuteSwitch.setOn(true, animated: true)
    thirtyMinuteSwitch.setOn(false, animated: true)
    // Do any additional setup after loading the view.
  }
  
  
  
  func configureNotification() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (success, error) in
      if success {
        print("notification access granted")
      } else {
        print(error?.localizedDescription as Any)
      }
    }
  }
  
  func scheduleNotification(timeInterval: TimeInterval, completion: @escaping (_ Success: Bool) -> ()) {
    let notif = UNMutableNotificationContent()
    
    notif.title = "PARKR"
    notif.subtitle = "Don't forget to move your vehicle!!!"
    notif.body = "Move your vehicle soon to avoid getting a ticket!! 🚘 🎫 👮"
    notif.sound = UNNotificationSound.init(named: "flowerdove-alert.caf")
    
    let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
    let request = UNNotificationRequest(identifier: "parkerNotification", content: notif, trigger: notificationTrigger)
    
    UNUserNotificationCenter.current().add(request) { (error) in
      if error != nil {
        print(error as Any)
        completion(false)
      } else {
        completion(true)
      }
    }
  }
  
  
}
