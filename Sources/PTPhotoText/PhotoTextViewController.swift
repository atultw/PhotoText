//
//  PhotoTextViewController.swift
//  phototext
//
//  Created by Atulya Weise on 2/1/24.
//

import Foundation
import SwiftUI
import Combine

public enum PTMode: String {
    case photo, manual
}

/// A text field that provides both keyboard and camera text-detection input modes.
///
/// Read and write the field's text content using the `text` binding. Do not edit the UITextView content directly.
///
///
/// > Note: This view does not provide a mode switcher for users to select between keyboard and text detection. You must use `setMode(_:)` to update the mode from outside.
///
/// The view controller's `view` is a UITextView, and you may access its properties as you would a regular text view.
/// > Caution: Only change the font using `setTextStyle(_:)`, as this method will recalculate the frame height for you.
///
///
///
/// - Properties:
///     - text: Binding to the text
///     - mode: Binding to the input mode (`PTMode`) - keyboard or camera
///     - placeholder: Text to be shown as a placeholder
public class PhotoTextViewController: UIViewController, UITextViewDelegate {
    
    var text: Binding<String>? = nil
    var height: Binding<CGFloat>? = nil
    var mode: PTMode = .manual
    var cameraVc = PTRecognitionCameraViewController()
    var textView = UITextView()
    var placeholderText: String?
    
    func setMode(_ mode: PTMode) {
        if self.textView.isFirstResponder {
            if mode == .photo && (self.textView.inputView == nil) {
                self.textView.resignFirstResponder()
                self.textView.inputView = cameraVc.view
                self.textView.becomeFirstResponder()
            } else if mode == .manual && (self.textView.inputView != nil) {
                self.textView.resignFirstResponder()
                self.textView.inputView = nil
                self.textView.becomeFirstResponder()
            }
        }
    }
    
    
    public func setTextStyle(_ textStyle: UIFont.TextStyle) {
        self.textView.font = UIFont.preferredFont(forTextStyle: textStyle)
        self.textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        self.placeholderLabel.font = UIFont.preferredFont(forTextStyle: textStyle)
        placeholderLabel.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        textView.sizeToFit()
        placeholderLabel.sizeToFit()
    }
    
    // MARK: Delegate
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        calculateHeight()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        textView.delegate = self
        textView.backgroundColor = .clear
        textView.isEditable = true
        textView.isSelectable = true
        textView.isUserInteractionEnabled = true
        textView.isScrollEnabled = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        placeholderLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        placeholderLabel.backgroundColor = .clear
        placeholderLabel.text = placeholderText
        placeholderLabel.isEditable = false
        placeholderLabel.isUserInteractionEnabled = false
        
        textView.addSubview(placeholderLabel)
        placeholderLabel.textColor = .tertiaryLabel
        placeholderLabel.isHidden = !textView.text.isEmpty
        
        
        cameraVc.didTapText = {
            self.text?.wrappedValue += $0
            self.textView.text = self.text?.wrappedValue ?? ""
            self.textView.insertText("") // to trigger height update
            return true
        }
        
        cameraVc.view.clipsToBounds = true
        //        modeSwitcherDelegate.calculateHeight(view: textView)
        //        textView.insertText("")
        self.view = textView
    }
    
    public func textViewDidChange(_ textView: UITextView) {
        text?.wrappedValue = textView.text
        calculateHeight()
        placeholderLabel.isHidden = !textView.text.isEmpty
    }
    
    
    //
    public func textViewDidEndEditing(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }
    
    public func textViewDidBeginEditing(_ textView: UITextView) {
        placeholderLabel.isHidden = true
    }
    
    // MARK: Internal
    
    private var placeholderLabel: UITextView = UITextView()
    
    private func calculateHeight() {
        
        let size = view.sizeThatFits(
            CGSize(
                width: view.frame.size.width,
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        
        guard self.height?.wrappedValue != size.height else { return }
        self.height?.wrappedValue = min(size.height, 500)
        view.frame.size.height = size.height
    }
}
