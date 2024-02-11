//
//  PTCameraViewController.swift
//  phototext
//
//  Created by Atulya Weise on 2/1/24.
//

import Foundation
import Combine
import CoreMotion
import UIKit
import AVFoundation
import Vision
import SwiftUI
import Accelerate

public enum PTSelection {
    case image(UIImage)
    case text(String)
}

public enum PTError: Error {
    case noCameraFound
    case other(String)
}

public class PTCameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var reportError: ((Error) -> ())? = nil
    var bufferSize: CGSize = .zero
    let session = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?
    let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    var videoDevice: AVCaptureDevice? = nil
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // to be implemented in the subclass
    }
    
    let pauseButtonWrapper = UIView()
    var pauseButton: UIImageView?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        try? setupAVCapture()
        let pauseButton = UIImageView(image: UIImage(systemName: "pause.fill")?
            .withConfiguration(UIImage.SymbolConfiguration(font: .preferredFont(forTextStyle: .title1)))
                                      
                                      , highlightedImage: UIImage(systemName: "play.fill")?
            .withConfiguration(UIImage.SymbolConfiguration(font: .preferredFont(forTextStyle: .title1))))
        
        self.view.addSubview(pauseButtonWrapper)
        pauseButtonWrapper.addSubview(pauseButton)
        
        pauseButtonWrapper.backgroundColor = UIColor.label.withAlphaComponent(0.9)
        
        //        let circle = CAShapeLayer()
        //        let circularPath = UIBezierPath(roundedRect: CGRect(x:0, y:0, width: pauseButtonWrapper.frame.size.width, height: pauseButtonWrapper.frame.size.height), cornerRadius:max(pauseButtonWrapper.frame.size.width, pauseButtonWrapper.frame.size.height))
        //        circle.path = circularPath.cgPath
        //        circle.fillColor = UIColor.black.cgColor
        //        circle.strokeColor = UIColor.black.cgColor
        //        circle.lineWidth = 0
        
        //        pauseButtonWrapper.layer.mask=circle
        
        self.view.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 10, right: 20)
        
        pauseButtonWrapper.translatesAutoresizingMaskIntoConstraints = false
        pauseButton.translatesAutoresizingMaskIntoConstraints = false
        
        pauseButton.contentMode = .scaleAspectFit
        pauseButton.trailingAnchor.constraint(equalTo: pauseButtonWrapper.layoutMarginsGuide.trailingAnchor).isActive = true
        pauseButton.bottomAnchor.constraint(equalTo: pauseButtonWrapper.layoutMarginsGuide.bottomAnchor).isActive = true
        
        pauseButtonWrapper.centerXAnchor.constraint(equalTo: pauseButton.centerXAnchor).isActive = true
        pauseButtonWrapper.centerYAnchor.constraint(equalTo: pauseButton.centerYAnchor).isActive = true
        
        pauseButtonWrapper.trailingAnchor.constraint(equalTo: self.view.layoutMarginsGuide.trailingAnchor).isActive = true
        pauseButtonWrapper.bottomAnchor.constraint(equalTo: self.view.layoutMarginsGuide.bottomAnchor).isActive = true
        
        pauseButtonWrapper.widthAnchor.constraint(equalTo: pauseButtonWrapper.heightAnchor).isActive = true
        pauseButtonWrapper.layoutIfNeeded()
        pauseButtonWrapper.layer.cornerRadius = pauseButtonWrapper.frame.size.width/2
        
        self.pauseButton = pauseButton
        
        self.view.bringSubviewToFront(pauseButtonWrapper)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.didTap(_:)))
        pauseButtonWrapper.addGestureRecognizer(tapGestureRecognizer)
        
    }
    
    @objc func didTap(_ sender: UITapGestureRecognizer? = nil) {
        cameraQueue.async {
            if self.session.isRunning {
                self.freezeFeed()
                
            } else {
                self.resumeFeed()
            }
        }
    }
    
    public override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setupAVCapture() throws {
        var deviceInput: AVCaptureDeviceInput!
        
        // Select a video device, make an input
        self.videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first
        if let videoDevice = videoDevice {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } else {
            throw PTError.noCameraFound
        }
        
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720 // Model image size is smaller.
        
        // Add a video input
        guard session.canAddInput(deviceInput) else {
            session.commitConfiguration()
            throw PTError.other("PhotoText: Failed to add video input to session")
        }
        session.addInput(deviceInput)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            // Add a video data output
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            session.commitConfiguration()
            throw PTError.other("PhotoText: Failed to add video output to session")
        }
        let captureConnection = videoDataOutput.connection(with: .video)
        // Always process the frames
        captureConnection?.isEnabled = true
        try videoDevice!.lockForConfiguration()
        let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice?.activeFormat.formatDescription)!)
        bufferSize.width = CGFloat(dimensions.width)
        bufferSize.height = CGFloat(dimensions.height)
        videoDevice!.unlockForConfiguration()
        session.commitConfiguration()
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer!.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.view.layer.addSublayer(previewLayer!)
    }
    
    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        previewLayer?.frame = self.view.frame
    }
    
    public func captureOutput(_ captureOutput: AVCaptureOutput, didDrop didDropSampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // print("frame dropped")
    }
    
    public func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation
        
        switch curDeviceOrientation {
        case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = .left
        case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
            exifOrientation = .upMirrored
        case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
            exifOrientation = .down
        case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
            exifOrientation = .up
        default:
            exifOrientation = .up
        }
        return exifOrientation
    }
    
    func zoomRange() -> (Double, Double) {
        return (Double(self.videoDevice?.minAvailableVideoZoomFactor ?? 0), Double(self.videoDevice?.maxAvailableVideoZoomFactor ?? 0))
    }
    
    func zoom(by factor: Double) throws {
        try self.videoDevice?.lockForConfiguration()
        self.videoDevice?.videoZoomFactor = factor
        self.videoDevice?.unlockForConfiguration()
    }
    
    fileprivate let cameraQueue = DispatchQueue(label: "camera_restart")
    
    
    public func freezeFeed() {
        self.session.stopRunning()
    }
    
    public func resumeFeed() {
        self.session.startRunning()
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        freezeFeed()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        resumeFeed()
        previewLayer?.position = self.view.layer.position
        previewLayer?.frame = self.view.frame
    }
}


// MARK: Vision

public class PTRecognitionCameraViewController: PTCameraViewController {
    
    public var didTapText: ((String) -> (Bool))? // return bool is whether it should be marked "used"
    public var didDragToSelect: (([String]) -> (Bool))?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.didPan(_:)))
        self.view.addGestureRecognizer(panGestureRecognizer)
        
        
        dragSelectionOverlay = CALayer()
        dragSelectionOverlay.name = "DragSelectionOverlay"
        dragSelectionOverlay.bounds = CGRect(x: 0.0,
                                             y: 0.0,
                                             width: bufferSize.width,
                                             height: bufferSize.height)
        dragSelectionOverlay.position = CGPoint(x: self.view.layer.bounds.midX, y: self.view.layer.bounds.midY)
        dragSelectionOverlay.zPosition = 3
        self.view.layer.addSublayer(dragSelectionOverlay)
    }
    
    private var panOrigin: CGPoint = CGPointZero
    
    @objc private func didPan(_ sender: UIPanGestureRecognizer) {
        dragSelectionOverlay.removeAllAnimations()
        switch sender.state {
        case .began:
            dragSelectionOverlay.backgroundColor = UIColor.systemCyan.withAlphaComponent(0.3).cgColor
            panOrigin = sender.location(in: self.view)
            self.freezeFeed()
        case .changed:
            dragSelectionOverlay.backgroundColor = UIColor.systemCyan.withAlphaComponent(0.3).cgColor
            dragSelectionOverlay.frame = CGRect(origin: panOrigin, size: CGSize(width: sender.translation(in: self.view).x, height: sender.translation(in: self.view).y))
        case .ended:
            dragSelectionOverlay.backgroundColor = UIColor.systemCyan.withAlphaComponent(0.5).cgColor
            dragSelectionOverlay.frame = CGRect(origin: panOrigin, size: CGSize(width: sender.translation(in: self.view).x, height: sender.translation(in: self.view).y))
            var selectedStrings = Array<String>()
            for layer in detectionOverlay?.sublayers ?? [] where layer is PTTextMatchLayer {
                if let layer = layer as? PTTextMatchLayer {
                    let minPt = layer.convert(CGPoint(x: layer.frame.minX, y: layer.frame.minY), to: self.view.layer)
                    let maxPt = layer.convert(CGPoint(x: layer.frame.maxX, y: layer.frame.maxY), to: self.view.layer)
                    
                    if dragSelectionOverlay.frame.contains(minPt) && dragSelectionOverlay.frame.contains(maxPt) {
                        if didTapText?(layer.textPayload) ?? false {
                            layer.didTap()
                        }
                        selectedStrings.append(layer.textPayload)
                    }
                }
            }
            didDragToSelect?(selectedStrings)
        default:
            break
        }
        
        //        self.dragSelectionOverlay.position = sender.location(in: self.view)
    }
    
    public override func freezeFeed() {
        cameraQueue.async {
            super.freezeFeed()
            try? self.imageRequestHandler?.perform(self.requests)
            self.cancellables.removeAll()
            self.moving = false
            DispatchQueue.main.async {
                self.pauseButton?.isHighlighted = true
            }
        }
    }
    
    public override func resumeFeed() {
        self.panOrigin = CGPointZero
        self.dragSelectionOverlay.frame = CGRectZero
        cameraQueue.async {
            super.resumeFeed()
            self.setupMotion()
            DispatchQueue.main.async {
                self.pauseButton?.isHighlighted = false
            }
        }
    }
    
    
    public override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let exifOrientation = exifOrientationFromDeviceOrientation()
        
        self.imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        self.pixelBuffer = pixelBuffer
    }
    
    private var detectionOverlay: CALayer! = nil
    private var dragSelectionOverlay: CALayer! = nil
    //    private var salientOverlay: CALayer! = nil
    private let motionQueue = OperationQueue()
    private var requests = [VNRequest]()
    private var transform = CGAffineTransform()
    private var imageRequestHandler: VNImageRequestHandler?
    private let motion = CMMotionManager()
    private let accelerometerData = PassthroughSubject<Double, Never>()
    private let gyroData = PassthroughSubject<CMGyroData, Never>()
    private var cancellables: Set<AnyCancellable> = []
    private var moving = true
    private var pixelBuffer: CVPixelBuffer?
    
    func processFrame() {
        do {
            try imageRequestHandler?.perform(self.requests)
        } catch {
            print(error)
        }
    }
    
    
    func setupMotion() {
        motion.startGyroUpdates(to: motionQueue, withHandler: {data, err in
            if let data = data {
                self.gyroData.send(data)
            }
        })
        
        listenForGyro()
    }
    
    func listenForGyro() {
        
        gyroData
            .collect(.byTime(DispatchQueue(label: "recognize"), .milliseconds(125))) // collect for 5 sec
            .map { dataArray in
                return (abs(dataArray.reduce(Double.zero, {$0 + $1.rotationRate.x}))
                        , abs(dataArray.reduce(Double.zero, {$0 + $1.rotationRate.y}))
                        , abs(dataArray.reduce(Double.zero, {$0 + $1.rotationRate.z})))
            }
            .sink { reading in
                let threshold = 1.1 - ((self.videoDevice!.videoZoomFactor - self.zoomRange().0) / (self.zoomRange().1 - self.zoomRange().0)) * 10
                if (reading.0 < threshold) && (reading.1 < threshold) && (reading.2 < threshold) {
                    if self.moving {
                        try? self.imageRequestHandler?.perform(self.requests)
                    }
                    self.moving = false
                }
            }
            .store(in: &cancellables)
        
        // clear
        gyroData
            .collect(.byTime(DispatchQueue(label: "clear"), .milliseconds(1000))) // collect for 5 sec
            .map { dataArray in
                return (abs(dataArray.reduce(Double.zero, {$0 + $1.rotationRate.x}))
                        , abs(dataArray.reduce(Double.zero, {$0 + $1.rotationRate.y}))
                        , abs(dataArray.reduce(Double.zero, {$0 + $1.rotationRate.z})))
            }
            .sink { reading in
                let threshold = 1.1 - ((self.videoDevice!.videoZoomFactor - self.zoomRange().0) / (self.zoomRange().1 - self.zoomRange().0)) * 10
                if !((reading.0 < threshold) && (reading.1 < threshold) && (reading.2 < threshold)) {
                    if !self.moving {
                        self.detectionOverlay.sublayers = nil
                    }
                    self.moving = true
                }
            }
            .store(in: &cancellables)
    }
    
    
    func setupVision() {
        
        let textRecognition = VNRecognizeTextRequest(completionHandler: { (request, error) in
            DispatchQueue.main.async {
                if let results = request.results {
                    self.drawVisionRequestResults(results)
                }
            }
        })
        
        //            let boxRecognition = VNGenerateObjectnessBasedSaliencyImageRequest(completionHandler: { (request, error) in
        //                DispatchQueue.main.async {
        //                    if let results = request.results {
        //                        self.drawSalientObjects(results)
        //                    }
        //                }
        //            })
        
        self.requests = [textRecognition]
        
    }
    
    func drawVisionRequestResults(_ results: [Any]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.sublayers = nil // remove all the old recognized objects
        for observation in results where observation is VNRecognizedTextObservation {
            guard let objectObservation = observation as? VNRecognizedTextObservation else {
                continue
            }
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
            
            let shapeLayer = self.plotObservation(observation as! VNRecognizedTextObservation, bounds: objectBounds)
            
            detectionOverlay.addSublayer(shapeLayer)
        }
        self.updateLayerGeometry()
        CATransaction.commit()
    }
    
    //    func drawSalientObjects(_ results: [Any]) {
    //        CATransaction.begin()
    //        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
    //        salientOverlay.sublayers = nil
    //
    //        for observation in results where observation is VNSaliencyImageObservation {
    //            guard let saliencyObservation = observation as? VNSaliencyImageObservation else {
    //                continue
    //            }
    //
    //            var unionOfSalientRegions = CGRect(x: 0, y: 0, width: 0, height: 0)
    //            let salientObjects = saliencyObservation.salientObjects ?? []
    //            for salientObject in salientObjects {
    //                let salientRect = VNImageRectForNormalizedRect(salientObject.boundingBox,
    //                                                               Int(bufferSize.width),
    //                                                               Int(bufferSize.height))
    //                let shapeLayer = self.plotObservation(observation as! VNSaliencyImageObservation, bounds: salientRect)
    //                salientOverlay.addSublayer(shapeLayer)
    //            }
    //        }
    //        self.updateLayerGeometry()
    //        CATransaction.commit()
    //    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            for layer in detectionOverlay?.sublayers ?? [] where layer is PTTextMatchLayer {
                if let layer = layer as? PTTextMatchLayer {
                    let pt = layer.convert(touch.location(in: self.view), from: self.view.layer)
                    if layer.contains(pt) {
                        if didTapText?(layer.textPayload) ?? false {
                            layer.didTap()
                        }
                    }
                }
            }
        }
    }
    
    
    override func setupAVCapture() throws {
        try super.setupAVCapture()
        
        // setup Vision parts
        setupVisionLayers()
        updateLayerGeometry()
        setupVision()
    }
    
    func setupVisionLayers() {
        detectionOverlay = CALayer()
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: bufferSize.width,
                                         height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: self.view.layer.bounds.midX, y: self.view.layer.bounds.midY)
        detectionOverlay.zPosition = 2
        self.view.layer.addSublayer(detectionOverlay)
        
        self.view.layer.zPosition = 0
        //
        //        salientOverlay = CALayer()
        //        salientOverlay.name = "SalientOverlay"
        //        salientOverlay.bounds = CGRect(x: 0.0,
        //                                       y: 0.0,
        //                                       width: bufferSize.width,
        //                                       height: bufferSize.height)
        //        salientOverlay.position = CGPoint(x: self.view.layer.bounds.midX, y: self.view.layer.bounds.midY)
        //        self.view.layer.addSublayer(salientOverlay)
        self.view.layer.masksToBounds = true
        self.view.clipsToBounds = true
    }
    
    func updateLayerGeometry() {
        let bounds = self.view.layer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        self.transform = CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale)
        // rotate the layer into screen orientation and scale and mirror
        detectionOverlay.setAffineTransform(transform)
        // center the layer
        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        //        salientOverlay.setAffineTransform(transform)
        // center the layer
        //        salientOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
        
    }
    
    func plotObservation(_ observation: VNRecognizedTextObservation, bounds: CGRect) -> CALayer {
        let shapeLayer = PTTextMatchLayer(textPayload: observation.topCandidates(1).first?.string ?? "")
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        return shapeLayer
    }
    
    //    func plotObservation(_ observation: VNSaliencyImageObservation, bounds: CGRect) -> CALayer {
    //        let shapeLayer = CALayer()
    //        shapeLayer.backgroundColor = UIColor.red.cgColor.copy(alpha: 0.4)
    //        shapeLayer.bounds = bounds
    //        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
    //        return shapeLayer
    //    }
    
    
}

private class PTTextMatchLayer: CALayer {
    var textPayload: String
    
    init(textPayload: String) {
        self.textPayload = textPayload
        super.init()
        self.name = "Found Object"
        self.backgroundColor = UIColor.yellow.cgColor.copy(alpha: 0.4)
        self.cornerRadius = 7
        
    }
    
    func didTap() {
        self.backgroundColor = UIColor.green.cgColor.copy(alpha: 0.4)
    }
    
    override init(layer: Any) {
        self.textPayload = (layer as! PTTextMatchLayer).textPayload
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
