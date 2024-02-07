//
//  PhotoTextField.swift
//  phototext
//
//  Created by Atulya Weise on 2/1/24.
//

import Foundation
import SwiftUI
import UIKit

/// A text field that provides both keyboard and camera text-detection input modes.
///
///
///
///
/// > Note: This view does not provide a mode switcher for users to select between keyboard and text detection. You must supply a binding to a `PTMode` and update it from another view, such as a segmented control picker.
///
/// - Parameters:
///     - text: Binding to the text
///     - mode: Binding to the input mode (PTMode) - keyboard or camera
///     - placeholder: Text to be shown as a placeholder
///     - textStyle: The font style to use in the text field and placeholder

public struct PhotoTextField: View {
    public init(text: Binding<String>, mode: Binding<PTMode>, placeholder: String, textStyle: UIFont.TextStyle) {
        self._text = text
        self._mode = mode
        self.placeholder = placeholder
        self.textStyle = textStyle
    }
    
    @State private var height: CGFloat = 100
    @Binding public var text: String
    @Binding public var mode: PTMode
    public var placeholder: String
    public var textStyle: UIFont.TextStyle
    
    
    public var body: some View {
        PhotoTextFieldInternal(text: $text, height: $height, mode: $mode, textStyle: textStyle)
            .frame(height: height)
    }
}

private struct PhotoTextFieldInternal: UIViewControllerRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    @Binding var mode: PTMode
    var textStyle: UIFont.TextStyle = .body
    
    public func makeUIViewController(context: Context) -> PhotoTextViewController {
        let vc = PhotoTextViewController()
        vc.text = $text
        vc.height = $height
        vc.placeholderText = "Test label"
        return vc
    }
    
    public func updateUIViewController(_ uiViewController: PhotoTextViewController, context: Context) {
        uiViewController.setTextStyle(textStyle)
        uiViewController.setMode(mode)
        
        if uiViewController.textView.text != self.text {
            uiViewController.textView.text = self.text
        }
    }
    
    public typealias UIViewControllerType = PhotoTextViewController
    
}
