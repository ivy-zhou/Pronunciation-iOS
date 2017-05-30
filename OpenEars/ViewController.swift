//
//  ViewController.swift
//  OpenEars
//
//  Created by Ivy Zhou on 2017-05-26.
//  Copyright © 2017 Ivy Zhou. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

class ViewController: UIViewController, OEEventsObserverDelegate {
    
    var fliteController = OEFliteController()
    var slt = Slt()
    var openEarsEventsObserver = OEEventsObserver()
    
    @IBOutlet weak var word: UILabel!
    @IBOutlet weak var pronunciationLabel: UILabel!
    @IBOutlet weak var partOfSpeech: UILabel!
    @IBOutlet weak var definition: UILabel!
    @IBOutlet weak var pronunciationRating: UILabel!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var listeningLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        // reloadWordData()
        self.activityIndicator.isHidden = true;
        regenLanguageModel()
        
        self.openEarsEventsObserver.delegate = self
    }
    
    @IBAction func getNextWord(_ sender: Any) {
        reloadWordData()
    }
    
    @IBAction func sayWord(_ sender: Any) {
        self.fliteController.say(_:self.word.text, with:self.slt)
    }
    
    private func reloadWordData() {
        self.activityIndicator.startAnimating()
        let headers: HTTPHeaders = [
            "X-Mashape-Key": Constants.MashapeKey,
            "Accept": "application/json"
        ]
        
        Alamofire.request("https://wordsapiv1.p.mashape.com/words/?hasDetails=definitions&random=true", headers:headers).responseJSON { response in
            self.activityIndicator.stopAnimating()
            if let json = response.data {
                print("JSON: \(response.result.value!)")
                
                let data = JSON(data: json)
                self.word.text = data["word"].string
                self.pronunciationLabel.text = data["pronunciation"]["all"].string;
                self.partOfSpeech.text = data["results"][0]["partOfSpeech"].string
                self.definition.text = data["results"][0]["definition"].string
                
                self.regenLanguageModel()
            }
        }
    }
    
    private func regenLanguageModel() {
        if OEPocketsphinxController.sharedInstance().isListening == true{
            OEPocketsphinxController.sharedInstance().stopListening();
        } else {
            let lmGenerator = OELanguageModelGenerator()
            let words = [self.word.text!] // These can be lowercase, uppercase, or mixed-case.
            let name = "NameIWantForMyLanguageModelFiles"
            let err: Error! = lmGenerator.generateLanguageModel(from: words, withFilesNamed: name, forAcousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"))
            
            if(err != nil) {
                print("Error while creating initial language model: \(err)")
            } else {
                let lmPath = lmGenerator.pathToSuccessfullyGeneratedLanguageModel(withRequestedName: name) // Convenience method to reference the path of a language model known to have been created successfully.
                let dicPath = lmGenerator.pathToSuccessfullyGeneratedDictionary(withRequestedName: name) // Convenience method to reference the path of a dictionary known to have been created successfully.
                
                do {
                    try OEPocketsphinxController.sharedInstance().setActive(true) // Setting the shared OEPocketsphinxController active is necessary before any of its properties are accessed.
                } catch {
                    print("Error: it wasn't possible to set the shared instance to active: \"\(error)\"")
                }
                // OEPocketsphinxController.sharedInstance().changeLanguageModel(toFile: <#T##String!#>, withDictionary: <#T##String!#>)
                OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: lmPath, dictionaryAtPath: dicPath, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false)
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // pulse the Listening button
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.duration = 0.75
        pulseAnimation.fromValue = 0
        pulseAnimation.toValue = 1
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        self.listeningLabel.layer.add(pulseAnimation, forKey: "animateOpacity")
    }
    
    func pocketsphinxDidReceiveHypothesis(_ hypothesis: String!, recognitionScore: String!, utteranceID: String!) { // Something was heard
        self.pronunciationRating.text = recognitionScore;
    }
    
    func pocketsphinxDidStopListening() {
        print("Local callback: Pocketsphinx has stopped listening.") // Log it.
        regenLanguageModel()
    }

}

