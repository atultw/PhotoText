//
//  PTCameraView.swift
//  phototext
//
//  Created by Atulya Weise on 2/1/24.
//

import Foundation
import SwiftUI
import UIKit

struct CameraView: UIViewControllerRepresentable {
    var sendReading: ((PTSelection) -> ())
//    @Binding var zoomMultiplier: Double
    @Binding var freeze: Bool
    
    func makeUIViewController(context: Context) -> PTRecognitionCameraViewController {
        let vc = PTRecognitionCameraViewController()
        vc.didTapText = {
            sendReading(.text($0))
            return true
        }
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: PTRecognitionCameraViewController, context: Context) {
//        let (lo, hi) = uiViewController.zoomRange()
//        do {
//            try uiViewController.zoom(by: lo + (1.0 / (1 + exp(-10 * (zoomMultiplier - 0.85))))*(hi-lo))
//        } catch {
//            print(error)
//        }
    }
    
    typealias UIViewControllerType = PTRecognitionCameraViewController
}
