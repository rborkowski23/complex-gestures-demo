import UIKit

import RxCocoa
import RxSwift

func makeSimpleButton() -> UIButton {
    let button = UIButton()
    button.titleLabel?.adjustsFontSizeToFitWidth = true
    button.layer.borderWidth = 1
    button.layer.cornerRadius = 4
    button.layer.borderColor = UIColor.black.cgColor
    button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    button.setTitleColor(UIColor.black, for: .normal)
    button.setTitleColor(UIColor.white, for: .highlighted)
    
    let _ = button.rx.observe(Bool.self, "highlighted", retainSelf: false)
        .distinctUntilChanged(==)
        .takeUntil(button.rx.deallocated)
        .subscribe(onNext: { isHighlighted in
            button.backgroundColor = (isHighlighted ?? false) ? UIColor.black : UIColor.white
        })
    
    return button
}
