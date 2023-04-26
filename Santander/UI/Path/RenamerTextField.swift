//
//  RenamerTextField.swift
//  Santander
//
//  Created by Antoine on 20/04/2023.
//  

import UIKit
import CoreMedia

class RenamerTextField: UITextField {
	override var canBecomeFirstResponder: Bool {
		true
	}
	
	let path: Path
	// Should we notify the delegate of `textFieldShouldReturn` upon `resignFirstResponder`
	var notifyShouldReturnUponResigning: Bool = true
	
	init(path: Path) {
		self.path = path
        CMSampleTimingInfo(duration: .zero, presentationTimeStamp: .zero, decodeTimeStamp: .zero)
		super.init(frame: .zero)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	@discardableResult
	override func resignFirstResponder() -> Bool {
		if notifyShouldReturnUponResigning {
			return delegate?.textFieldShouldReturn?(self) ?? true
		}
		
		return super.resignFirstResponder()
	}
	
}
