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
    
    var timer: Timer!
    
    var secondsLeft: Int!
    
    var hour: Int!
    var minute: Int!
    var second: Int!
    
    @IBOutlet weak var tenMinuteSwitch: UISwitch!
    @IBOutlet weak var fifteenMinuteSwitch: UISwitch!
    @IBOutlet weak var thirtyMinuteSwitch: UISwitch!
    
    
    @IBAction func tenMinuteAction(_ sender: UISwitch) {
        if sender.isOn {
            tenMinuteSwitch.setOn(true, animated: false)
            scheduleNotification(timeInterval: 5, completion: { (success) in
                if success {
                    print("successfully scheduled notification")
                } else {
                    print("Error scheduling notification")
                }
            })
        }
    }
    
    @IBAction func fifteenMinuteAction(_ sender: UISwitch) {
    }
    @IBAction func thirtyMinuteAction(_ sender: UISwitch) {
    }
    
    
    @IBAction func stopAction(_ sender: UIButton) {
        // TODO: Stop the timer
        print("Stop button pressed")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        secondsLeft = 16925
        
        self.cofigureNotification()
        
        tenMinuteSwitch.setOn(false, animated: true)
        fifteenMinuteSwitch.setOn(false, animated: true)
        thirtyMinuteSwitch.setOn(false, animated: true)
        // Do any additional setup after loading the view.
    }
    
    func updateTimer() {
        if secondsLeft > 0 {
            secondsLeft = secondsLeft - 1
            hour = secondsLeft / 3600
            minute = (secondsLeft % 3600) / 60
            second = (secondsLeft % 3600) % 60
        } else {
            secondsLeft = 16925
        }
    }
    
        
    func cofigureNotification() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (success, error) in
            if success {
                print("notification access granted")
            } else {
                print(error?.localizedDescription)
            }
        }
    }
    
    func scheduleNotification(timeInterval: TimeInterval, completion: @escaping (_ Success: Bool) -> ()) {
        let notif = UNMutableNotificationContent()
        
        
        
        notif.title = "PARKR"
        notif.subtitle = "It's time to move out!!!"
        notif.body = "Your parking time limit has been reached, it is time to move out your car. unless if you want parking ticket.:)"
        
        let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: "parkerNotification", content: notif, trigger: notificationTrigger)
        
        UNUserNotificationCenter.current().add(request) { (error) in
            if error != nil {
                print(error)
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    
}
