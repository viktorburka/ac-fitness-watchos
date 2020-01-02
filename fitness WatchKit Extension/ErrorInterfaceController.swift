//
//  ErrorInterfaceController.swift
//  fitness WatchKit Extension
//
//  Created by Viktor Burka on 1/2/20.
//  Copyright © 2020 Viktor Burka. All rights reserved.
//

import WatchKit
import Foundation


class ErrorInterfaceController: WKInterfaceController {

    @IBOutlet weak var errorLabel: WKInterfaceLabel!
    
    @IBAction func closePressed() {
        dismiss()
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
        let text = context as! String?
        if let errorText = text {
            errorLabel.setText(errorText)
        }
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

}
