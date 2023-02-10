//
//  ViewController.swift
//  NCSlider
//
//  Created by Kavya Prabha S on 31/10/22.
//

import UIKit

protocol UpdateSliderProtocol {
    func updateSliderValue(value: Int)
}

protocol UpdateTextFieldValue {
    func setSliderValue(to: Int)
}

class ViewController: UIViewController {
    
    @IBOutlet weak var sliderTextField: UITextField!
    @IBOutlet weak var customSlider: StepSlider!
    
    var delegate: UpdateTextFieldValue!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        customSlider.delegate = self
        sliderTextField.delegate = self
        sliderTextField.keyboardType = .phonePad
        delegate = customSlider.self
        hideKeyboardWhenTappedAround()
    }
}

extension ViewController: UpdateSliderProtocol {
    func updateSliderValue(value: Int) {
        sliderTextField.text = "\(value)"
    }
}

extension ViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {

    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
      textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        let textValue = Int(textField.text ?? "120") ?? 120
        delegate.setSliderValue(to: textValue)
    }

}

extension UIViewController {
    func hideKeyboardWhenTappedAround() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}



