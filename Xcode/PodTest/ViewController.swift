//
//  ViewController.swift
//  PodTest
//
//  Created by Pietro Calzini on 04/02/2017.
//  Copyright © 2017 Pietro Calzini. All rights reserved.
//

import UIKit
import SocketIO
import AVFoundation
import Speech

class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    
    @IBOutlet var recordButton: UIButton!
    @IBOutlet var statusLabel: UILabel!
    let captureSession = AVCaptureSession()
    var previewLayer : AVCaptureVideoPreviewLayer?
    let speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    let output = AVCaptureStillImageOutput()
    var gameTimer: Timer!
    let audioSession = AVAudioSession.sharedInstance()
    var isRunningVideo = true
    var start = false
    var label = UILabel(frame: CGRect(x: 20, y: 20, width: 300, height: 21))
   
    let speechSynthesizer = AVSpeechSynthesizer()
    let socket = SocketIOClient(socketURL: URL(string: "http://horus-vision.southcentralus.cloudapp.azure.com:8080")!, config: [.log(true), .forcePolling(true)])
    
    @IBOutlet var startCaptureButton: UIButton!
    
    // If we find a device we'll store it here for later use
    var captureDevice : AVCaptureDevice?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        captureSession.sessionPreset = AVCaptureSessionPreset640x480
        
        speechRecognizer?.delegate = self  //3
        SFSpeechRecognizer.requestAuthorization { (authStatus) in  //4
                print(authStatus)
        }
            
        let screenSize: CGRect = UIScreen.main.bounds
        let boundaries = CGRect(x: (screenSize.width - 350)/2, y: 450, width: 350, height: 60)
        let view = UIView(frame: boundaries)
        view.backgroundColor = UIColor.white
        view.alpha = 0.7
        view.layer.cornerRadius = 8
        view.addSubview(label)
        self.view.addSubview(view)

        
        socket.connect()
        socket.on("connect") {data, ack in
            self.statusLabel.text = "Connected"
        }
        
        let devices = AVCaptureDevice.devices()
        
        // Loop through all the capture devices on this phone
        for device in devices! {
            // Make sure this particular device supports video
            if ((device as AnyObject).hasMediaType(AVMediaTypeVideo)) {
                // Finally check the position and confirm we've got the back camera
                if((device as AnyObject).position == AVCaptureDevicePosition.back) {
                    captureDevice = device as? AVCaptureDevice
                    if captureDevice != nil {
                        beginSession()
                    }
                }
            }
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let screenSize: CGRect = UIScreen.main.bounds
        let boundaries = CGRect(x: (screenSize.width - 350)/2, y: 450, width: 350, height: 60)
        let view = UIView(frame: boundaries)
        view.backgroundColor = UIColor.white
        view.alpha = 0.7
        view.layer.cornerRadius = 8
        view.addSubview(self.label)
        self.view.addSubview(view)
    }
    
    //Emit a message to the socket
    func send(stringToSend: String) {
        self.socket.emit("client:message", stringToSend )
    }
    
    //Pronounce a String passed as a parameter
    func pronounceText(textToPronounce: String){
        do {
            try self.audioSession.setCategory(AVAudioSessionCategoryPlayback)
            try self.audioSession.setMode(AVAudioSessionModeSpokenAudio)
            try self.audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        let speechUtterance = AVSpeechUtterance(string: textToPronounce)
        speechUtterance.rate = 0.5
        speechUtterance.volume = 1
        speechUtterance.pitchMultiplier = 0.25
        speechUtterance.voice = AVSpeechSynthesisVoice(identifier: AVSpeechSynthesisVoiceIdentifierAlex)
        speechSynthesizer.speak(speechUtterance)
    }
    
    //Listen to the server
    func listenToServer(){
        let start = self.currentTimeMillis();
        socket.on("server:message") {data, ack in
            let result = data[0] as! String
            self.label.adjustsFontSizeToFitWidth = true

            self.label.text = result
            print(result)
            self.pronounceText(textToPronounce: result)
            self.recordButton.isEnabled = true
            self.recordButton.setTitle("Start Recording", for: .normal)
        }
    }
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
        } else {
            recordButton.isEnabled = false
        }
    }
    
    ////Create connection to socket **** TESTING ONLY *****
    @IBAction func connect(_ sender: Any) {
        if(!isRunningVideo) {
            self.captureSession.startRunning()
        }
        pronounceText(textToPronounce: "Say something, I'm listening!" )
        gameTimer = Timer.scheduledTimer(timeInterval: 2.5, target: self, selector: #selector(startSpeech), userInfo: nil, repeats: false)
    }
    
    func startSpeech() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("Start Recording", for: .normal)
        } else {
            startRecording()
            recordButton.setTitle("Stop Recording", for: .normal)
        }
}
    
    func startRecording() {
        self.label.text = ""
        
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        do {
            try self.audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try self.audioSession.setMode(AVAudioSessionModeMeasurement)
            try self.audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let inputNode = audioEngine.inputNode else {
            fatalError("Audio engine has no input node")
        }
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            
            var isFinal = false
            
            if result != nil {
                
                let eval = result?.bestTranscription.formattedString == "What's in front of me"
                if(eval==true) {
                    self.takePhoto()
                    isFinal = true
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Processing...", for: .normal)
                    self.pronounceText(textToPronounce: "Processing, please wait")

                }
                
                self.label.text = result?.bestTranscription.formattedString
                isFinal = (result?.isFinal)!
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
            }
        })
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
        
        self.label.text = "Say something, I'm listening!"
        
    }

    
    //Show a rectangle to identify an object
    func showPositionRectangle(x: Int, y: Int, w: Int, h: Int){
        
        let rect = CGRect(x: x, y:y, width: w, height: h)
        let view = UIView(frame: rect)
        view.layer.borderWidth = 3
        view.layer.cornerRadius = 3
        view.layer.borderColor = UIColor.red.cgColor

        self.view.addSubview(view)
    }
    
    //Start capturing images
    @IBAction func startCapturing(_ sender: Any) {
        
        if(!start){
            start = true
            takePhoto()
            startCaptureButton.setTitle("Processing...", for: UIControlState.normal)
            startCaptureButton.isEnabled = false
        }
        
    }
    
    func base64Encoded(data: Data) -> String? {
        return data.base64EncodedString()
    }
    
    func takePhoto() {
        output.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        
        if captureSession.canAddOutput(output)
        {
            captureSession.addOutput(output)
        }
        
        let videoConnection = output.connection(withMediaType: AVMediaTypeVideo)
        
        if videoConnection != nil {
            output.captureStillImageAsynchronously(from: output.connection(withMediaType: AVMediaTypeVideo))
            { (imageDataSampleBuffer, error) -> Void in
                
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)

                self.captureSession.stopRunning()
                self.isRunningVideo = false;
                let base64Image = self.base64Encoded(data: imageData!)
                
                self.send(stringToSend: base64Image!)
                self.listenToServer()
                
            }
        }
    }
    
    func currentTimeMillis() -> Int64{
        let nowDouble = NSDate().timeIntervalSince1970
        return Int64(nowDouble*1000)
    }
    
    func beginSession() {
        let err : NSError? = nil
        
        do{
            try captureSession.addInput(AVCaptureDeviceInput(device: captureDevice))
        } catch {
            print("NOT POSSIBLE TO ACTIVATE");
        }
        
        if err != nil {
            print("Error")
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.view.layer.addSublayer(previewLayer!)
        previewLayer?.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height - 100)
        captureSession.startRunning()
    }
}


