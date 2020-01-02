//
//  WorkoutScreenInterfaceController.swift
//  fitness WatchKit Extension
//
//  Created by Viktor Burka on 12/27/19.
//  Copyright © 2019 Viktor Burka. All rights reserved.
//

import WatchKit
import HealthKit
import Foundation

class WorkoutScreenInterfaceController: WKInterfaceController {
    
    private var healthStore: HKHealthStore
    private var session: HKWorkoutSession?
    private var ws: WorkoutSession
    private var wd: WorkoutData
    private var timer: Timer?
    private var processing: Bool = false
    private var httpSender: HttpSender
    
    @IBOutlet weak var displayTimer: WKInterfaceTimer!
    @IBOutlet weak var displayBPM: WKInterfaceLabel!
    
    override init() {
        print("WorkoutScreenInterfaceController: init")
        healthStore = HKHealthStore()
        ws = WorkoutSession(startDate: Date(), endDate: Date(), state: "stopped")
        wd = WorkoutData()
        httpSender = HttpSender()
        super.init()
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        print("WorkoutScreenInterfaceController: awake")
        let allTypes = Set([HKObjectType.workoutType(),
                            HKObjectType.quantityType(forIdentifier: .heartRate)!])
        
        healthStore.requestAuthorization(toShare: allTypes, read: allTypes) { (success, error) in
            if !success {
                print("error request auth for health data!")
                self.pop()
            }
        }
        
        showSpinner(text: "Starting workout...")
        startWorkout() {
            error in
            self.hideSpinner()
            if let error = error {
                self.endWorkout(dueToFailure: true) { _ in }
                print(error)
                self.showError(text: error)
                self.pop()
                return
            }
        }
    }

    override func willActivate() {
        print("WorkoutScreenInterfaceController: willActivate")
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        print("WorkoutScreenInterfaceController: didDeactivate")
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
//        askToStopWorkout() {
//            yes in
//            if yes {
//
//            }
//        }
    }
    
    private func startWorkout(result: @escaping (String?) -> Void) {
        startTrackingWorkout() {
            error in
            if let error = error {
                result(error)
                return
            }
            self.displayTimer.start()
            result(nil)
        }
    }
    
    private func endWorkout(dueToFailure: Bool, result: @escaping (String?) -> Void) {
        stopTrackingWorkout(dueToFailure: dueToFailure, result: result)
        displayTimer.stop()
    }

    @IBAction func endWorkoutPressed() {
        showSpinner(text: "finishing workout...")
        endWorkout(dueToFailure: false) {
            error in
            self.hideSpinner()
            if let error = error {
                self.showError(text: error)
            }
            self.reset()
            self.pop()
        }
    }
    
    private func startTrackingWorkout(result: @escaping (String?) -> Void) {
        
        ws.startDate = Date()
        ws.state = "running"
        
        httpSender.sendNow(data: ws) {
            error, httpCode in
            
            if let error = error {
                print(error)
                result("Can't start workout: server unresponsive")
                return
            }
            
            print("<- state:", self.ws.state)
            
            let conf = HKWorkoutConfiguration()
            conf.activityType = .other
            
            guard let workoutSession = try? HKWorkoutSession(healthStore: self.healthStore, configuration: conf) else {
                result("can't create workout session")
                return
            }
            
            workoutSession.startActivity(with: self.ws.startDate)
            self.session = workoutSession
            
            self.timer = Timer(timeInterval: 1.0, target: self, selector: #selector(self.reportWorkoutData),
                               userInfo: nil, repeats: true)
            RunLoop.main.add(self.timer!, forMode: RunLoop.Mode.common)
            
            print("workout session created")
            result(nil)
        }
    }
    
    @objc func reportWorkoutData() {
        print("tick...")
        // check whether the previous operation has finished yet
        if self.processing {
            print("request in progress. skipping...")
            return
        }
        // set processing flag to block any concurrent operations
        self.processing = true

        self.readHeartRate() {
            heartRate, error in

            if let error = error {
                print(error)
                self.processing = false
                self.displayBPM.setText("--BPM")
                return
            }

            self.wd.heartRate = heartRate

            print("current heart rate: \(self.wd.heartRate)BPM")
            self.displayBPM.setText("\(self.wd.heartRate)BPM")

            // send workout data to the server
            self.httpSender.sendNow(data: self.wd) {
                error, httpCode in
                // unblock further heart rate processing
                self.processing = false
                if let error = error {
                    print(error)
                    return
                }
                print("successfully sent workout data: \(heartRate)")
            }
        }
    }
    
    private func stopTrackingWorkout(dueToFailure: Bool, result: @escaping (String?) -> Void) {
        if let t = timer {
            t.invalidate()
        }
        if let s = session {
            let endDate = Date()
            s.stopActivity(with: endDate)
            session = nil
            ws.endDate = endDate
        }
        ws.state = "stopped"
        if !dueToFailure {
            httpSender.cancelLast()
            httpSender.sendNow(data: ws) {
                error, _ in
                if let error = error {
                    result(error)
                    return
                }
                result(nil)
            }
            return
        }
        result(nil)
    }
    
    private func readHeartRate(result: @escaping (Int,String?) -> Void) {

        let heartRateUnit = HKUnit(from: "count/min")
        let predicate = HKQuery.predicateForSamples(withStart: ws.startDate, end: nil, options: [])

        guard let sampleType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else {
            result(-1, "can't init quantity type for HKQuantityTypeIdentifier.heartRate")
            return
        }
        
        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: Int(HKObjectQueryNoLimit), sortDescriptors: nil) {
            query, results, error in
            
            if let error = error {
                result(-1, "\(error)")
                return
            }
            
            guard let samples = results as? [HKQuantitySample] else {
                result(-1, "can't convert resulting samples to [HKQuantitySample] type")
                return
            }

            if let event = samples.last {
                // read heart rate with the specified unit
                let heartRate = event.quantity.doubleValue(for: heartRateUnit)
                // update 'read from' position
                self.ws.startDate = event.endDate
                // return heart rate to the caller
                result(Int(heartRate), nil)
                return
            }
            
            result(-1, "no heart rate data available")
        }
        
        healthStore.execute(query)
    }
    
    private func showSpinner(text: String) {
        presentController(withName: "SpinnerModal", context: text)
    }
    
    private func hideSpinner() {
        dismiss()
    }
    
    private func showError(text: String) {
        presentController(withName: "ErrorModal", context: text)
    }
    
    private func reset() {
        if let workoutSession = session {
            workoutSession.stopActivity(with: Date())
        }
        if let updatesTimer = timer {
            updatesTimer.invalidate()
        }
        ws.state = "stopped"
        ws.startDate = Date()
        ws.endDate = Date()
        processing = false
    }
}

class HttpSender {
    var sending: Bool = false
    let url = URL(string: "http://cosml-1686857.local:8080/api/v1/workout")!
    var request: URLRequest
    var task: URLSessionUploadTask
    
    init() {
        request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10.0)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        task = URLSessionUploadTask()
    }
    
    func sendNow(data: TransferData, result: @escaping (_ error: String?, _ httpCode: Int) -> Void) {
        sending = true
        send(data: data) {
            error, httpCode in
            self.sending = false
            result(error, httpCode)
        }
    }
    
    func cancelLast() {
        task.cancel()
    }
    
    private func send(data: TransferData, result: @escaping (_ error: String?, _ httpCode: Int) -> Void) {
        // serialize data to transfer
        guard let td = serialize(data: data) else {
            return
        }
        // determine workout state param
        let ws = state(data: data)
        // create url with 'state' query param
        request.url = URL(string: "http://cosml-1686857.local:8080/api/v1/workout?state=" + ws)!
        print("sending to:", request.url!)
        // send http request
        task = URLSession.shared.uploadTask(with: request, from: td) {
            data, response, error in
            
            if let error = error {
                result("\(error)", -1)
                return
            }
            guard let response = response as? HTTPURLResponse else {
                result("can't convert http response to HTTPURLResponse", -1)
                return
            }
            if !(200...299).contains(response.statusCode) {
                result(HTTPURLResponse.localizedString(forStatusCode: response.statusCode), response.statusCode)
                return
            }
            result(nil, response.statusCode)
        }
        task.resume()
    }
    
    private func serialize(data: TransferData) -> Data? {
        switch data.type() {
        case .workoutSession:
            guard let ws = data as? WorkoutSession else {
                return nil
            }
            guard let uploadData = try? JSONEncoder().encode(ws) else {
                return nil
            }
            return uploadData
        case .workoutData:
            guard let wd = data as? WorkoutData else {
                return nil
            }
            guard let uploadData = try? JSONEncoder().encode(wd) else {
                return nil
            }
            return uploadData
        }
    }
    
    private func state(data: TransferData) -> String {
        switch data.type() {
        case .workoutSession:
            let ws = data as? WorkoutSession
            if ws?.state == "running" {
                return "start"
            }
            return "end"
        case .workoutData:
            return "update"
        }
    }
}

enum TransferDataType {
    case workoutData, workoutSession
}

protocol TransferData {
    func type() -> TransferDataType
}

struct WorkoutSession: Codable, TransferData {
    var startDate: Date
    var endDate: Date
    var state: String // running, stopped
    
    func type() -> TransferDataType {
        return .workoutSession
    }
}

struct WorkoutData: Codable, TransferData {
    var heartRate: Int
    
    init() {
        self.heartRate = 0
    }
    
    func type() -> TransferDataType {
        return .workoutData
    }
}
