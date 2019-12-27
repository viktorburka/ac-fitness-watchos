//
//  InterfaceController.swift
//  fitness WatchKit Extension
//
//  Created by Viktor Burka on 12/20/19.
//  Copyright © 2019 Viktor Burka. All rights reserved.
//

import WatchKit
import Foundation
import HealthKit

class InterfaceController: WKInterfaceController {
    
    @IBOutlet weak var startWorkoutButton: WKInterfaceButton!
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        startWorkoutButton.setEnabled(HKHealthStore.isHealthDataAvailable())
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    // Mark: Actions
    @IBAction func startWorkout() {
//        presentController(withName: "WorkoutScreen", context: nil)
    }
    
}
