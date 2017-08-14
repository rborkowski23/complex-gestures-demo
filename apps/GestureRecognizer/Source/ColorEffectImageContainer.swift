import UIKit

import RxDataSources
import RxSwift
import SnapKit

/**
 * Allows us to use an image as a mask and set its color, similar to text.
 * Image is displayed in the subview `imageView` which should be positioned and
 * sized in the container as the user wishes. Default size is image's size.
 */
class ColorEffectImageContainer: UIView {
    private var disposeBag = DisposeBag()
    
    lazy var imageView: ColorEffectImageView = {
        return ColorEffectImageView(container: self)
    }()
    
    var image: UIImage? {
        didSet {
            imageView.setNeedsDisplay()
            remakeImageViewConstraints()
        }
    }
    var blendMode: CGBlendMode {
        didSet {
            imageView.setNeedsDisplay()
        }
    }
    var fillColor: UIColor = .white {
        didSet {
            imageView.setNeedsDisplay()
        }
    }
    
    enum ImageViewSizing {
        case intrinsic
        case scaleFit
        case scaleFill
    }
    var imageViewSizing: ImageViewSizing = .intrinsic {
        didSet {
            imageView.setNeedsDisplay()
            remakeImageViewConstraints()
        }
    }
    
    private var imageViewConstraints = [Constraint]()
    
    public init(image: UIImage?, blendMode: CGBlendMode = .multiply) {
        self.image = image
        self.blendMode = blendMode
        
        super.init(frame: CGRect.zero)
        
        isUserInteractionEnabled = false
        clipsToBounds = true
        
        addSubview(imageView)
        remakeImageViewConstraints()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func makeDefaultImageViewConstraints() {
        imageView.snp.makeConstraints { (make) in
            make.size.equalToSuperview()
            make.center.equalToSuperview()
        }
    }
    
    func centerImageView() {
        imageView.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
        }
    }
    
    private func remakeImageViewConstraints() {
        for constraint in imageViewConstraints {
            constraint.deactivate()
        }
        
        imageViewConstraints = []
        
        imageView.snp.makeConstraints { (make) in
            let imageSize = image?.size ?? CGSize.zero
            let sizing = imageViewSizing
            
            if sizing == .intrinsic {
                imageViewConstraints.append(make.width.equalTo(imageSize.width).constraint)
                imageViewConstraints.append(make.height.equalTo(imageSize.height).constraint)
                
                return
            }
            
            var aspectRatio = imageSize.height / imageSize.width
            
            if !aspectRatio.isFinite {
                aspectRatio = 0
            }
            
            imageViewConstraints.append(
                make.height.equalTo(imageView.snp.width).multipliedBy(aspectRatio).constraint)
            
            if aspectRatio > 0 && (sizing == .scaleFit || sizing == .scaleFill) {
                if aspectRatio > 1 || (aspectRatio <= 1 && sizing == .scaleFill) {
                    imageViewConstraints.append(make.height.equalToSuperview().constraint)
                } else {
                    imageViewConstraints.append(make.width.equalToSuperview().constraint)
                }
            }
        }
    }
}

class ColorEffectImageView: UIView {
    weak var container: ColorEffectImageContainer?
    
    public init(container: ColorEffectImageContainer) {
        super.init(frame: CGRect.zero)
        
        isOpaque = false
        
        self.container = container
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: UIView
    
    override open func draw(_ rect: CGRect) {
        super.draw(rect)
        
        let ctx = UIGraphicsGetCurrentContext()
        
        ctx?.setFillColor(UIColor(red: 1, green: 1, blue: 1, alpha: 0).cgColor)
        ctx?.fill(bounds)
        
        if let container = container, let image = container.image {
            let drawRect = CGRect(origin: CGPoint.zero, size: bounds.size)
            
            image.draw(in: drawRect, blendMode: .normal, alpha: container.fillColor.cgColor.alpha)
            
            ctx?.translateBy(x: 0, y: drawRect.size.height)
            ctx?.scaleBy(x: 1, y: -1)
            ctx?.clip(to: drawRect, mask: image.cgImage!)
            ctx?.setFillColor(container.fillColor.cgColor)
            ctx?.setBlendMode(container.blendMode)
            ctx?.fill(drawRect)
        }
    }
}
