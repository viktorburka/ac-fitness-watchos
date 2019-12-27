//
//  ViewController.swift
//  fitness
//
//  Created by Viktor Burka on 12/20/19.
//  Copyright © 2019 Viktor Burka. All rights reserved.
//

import UIKit
import HealthKit

class ViewController: UIViewController {
    
    private var healthStore: HKHealthStore?

    override func viewDidLoad() {
        super.viewDidLoad()

        if HKHealthStore.isHealthDataAvailable() {
            print("HK available")
            healthStore = HKHealthStore()
        } else {
            print("HK *not* available")
            return
        }

        let allTypes = Set([HKObjectType.workoutType(),
                            HKObjectType.quantityType(forIdentifier: .heartRate)!])

        guard let hk = healthStore else {
            fatalError("*** Unable to get the health store type ***")
        }

        hk.requestAuthorization(toShare: allTypes, read: allTypes) { (success, error) in
            if !success {
                print("error request auth for health data!")
            }
        }
    }
}
