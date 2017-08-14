import UIKit

import HEXColor
import RxCocoa
import RxSwift
import SnapKit

class ComplexGestureInput: NSObject, UIGestureRecognizerDelegate {
    var disposeBag = DisposeBag()

    let flatTapRecognizer = FlatTapRecognizer()
    fileprivate let trackOneTouchRecognizer = TrackOneTouchGestureRecognizer()
    
    private weak var _view: UIView?
    var view: UIView? {
        get {
            return _view
        }
        set(newValue) {
            if let view = _view {
                unlink(view: view)
            }
            
            _view = newValue
            
            if let view = _view {
                link(view: view)
            }
        }
    }
    
    private var viewDisposeBag = DisposeBag()
    
    private(set) var previewView = UIView()
    private var previewSubviews = [GesturePreviewView]()
    private var currentPreviewSubview: GesturePreviewView? {
        return previewSubviews.last
    }
    
    private var currentDrawingVar = Variable<Drawing>(Drawing())
    var currentDrawing: Observable<Drawing> {
        return currentDrawingVar.asObservable()
    }
    
    private var currentStroke = Stroke()
    
    private var didStartStrokeSubject = PublishSubject<Void>()
    var didStartStroke: Observable<Void> {
        return didStartStrokeSubject.asObservable()
    }
    
    lazy var canPreventRecognizerWhileGesturing: (UIGestureRecognizer) -> Bool = { _ in
        return true
    }
    
    var isGesturing = Variable<Bool>(false)
//    var isGesturing: Observable<Bool> {
//        return isGesturingVar.asObservable()
//    }
    
    var switchStatesOnFlatTap = true
    
    override init() {
        super.init()
        
        flatTapRecognizer.addTarget(self, action: #selector(flatTap))
        trackOneTouchRecognizer.addTarget(self, action: #selector(trackedTouchAction))
        // Only allow flatTapRecognizer to simultaneously receive touches.
        trackOneTouchRecognizer.canPreventFunc = { [weak self] recognizer -> Bool in
            guard let me = self else {
                return false
            }
            
            if recognizer == me.flatTapRecognizer {
                return false
            }
            
            return me.canPreventRecognizerWhileGesturing(recognizer)
        }
        
        previewView.isUserInteractionEnabled = false
        
        isGesturing
            .asObservable()
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] isGesturing in
                self?.trackOneTouchRecognizer.isEnabled = isGesturing
                self?.clear()
            })
            .disposed(by: disposeBag)
    }
    
    private func link(view: UIView) {
        view.addGestureRecognizer(flatTapRecognizer)
        view.addGestureRecognizer(trackOneTouchRecognizer)
        
        view.rx.deallocated
            .subscribe(onNext: { [weak self] _ in
                self?.unlink(view: nil)
            })
            .disposed(by: viewDisposeBag)
    }
    
    /**
     * Unlink from the view.
     *
     * - parameter view: The view to unlink from. May be nil if this method was
     * called due to it being deallocated.
     */
    private func unlink(view: UIView?) {
        view?.removeGestureRecognizer(flatTapRecognizer)
        view?.removeGestureRecognizer(trackOneTouchRecognizer)
        
        viewDisposeBag = DisposeBag()
    }
    
    private func fadePreviewSubview(subview: GesturePreviewView) {
        subview.isOpaque = false
        
        UIView.animate(withDuration: 0.25, animations: {
                subview.layer.opacity = 0
            }, completion: { [weak self] _ in
                subview.removeFromSuperview()
                
                if let index = self?.previewSubviews.index(of: subview) {
                    self?.previewSubviews.remove(at: index)
                }
            })
    }
    
    func clear() {
        if let previewSubview = currentPreviewSubview {
            fadePreviewSubview(subview: previewSubview)
        }
        
        let subview = GesturePreviewView()
        previewSubviews.append(subview)
        previewView.addSubview(subview)
        
        subview.snp.makeConstraints({ (make) in
            make.size.equalToSuperview()
            make.center.equalToSuperview()
        })
        
        currentDrawingVar.value = Drawing()
        currentStroke = Stroke()
    }
    
    @objc private func flatTap() {
        if switchStatesOnFlatTap {
            isGesturing.value = !isGesturing.value
        }
    }
    
    @objc private func trackedTouchAction(_ recognizer: TrackOneTouchGestureRecognizer) {
        guard let view = view, recognizer.isEnabled else {
            return
        }
        
        let state = recognizer.state
        let goodStateAfterPossible = (state == .began || state == .changed || state == .ended)
        
        if goodStateAfterPossible, let touch = recognizer.touch {
            if currentStroke.samples.count == 0 {
                didStartStrokeSubject.onNext(())
            }
            
            currentStroke.samples.append(
                TouchSample(
                    time: touch.timestamp,
                    position: touch.location(in: view),
                    majorRadius: Double(touch.majorRadius)
                )
            )
        }
        
        if state == .ended {
            if currentStroke.samples.count > 0 {
                currentDrawingVar.value.strokes.append(currentStroke)
            }
            
            currentStroke = Stroke()
        }
        
        if let previewSubview = currentPreviewSubview {
            if goodStateAfterPossible {
                previewSubview.updateTouch(touchPosition: recognizer.location(in: previewSubview))
            }
            
            if state == .ended {
                previewSubview.endTouch()
            }
        }
    }
}

fileprivate class GesturePreviewView: UIView {
    private var imageView: UIImageView!

    private var currentTouch: UITouch?
    private var lastPosition: CGPoint?
    
    var strokeColor: UIColor = UIColor("#7DC1F8")

    init() {
        super.init(frame: CGRect.zero)
        
        isOpaque = false
        layer.opacity = 0.5
        
        isUserInteractionEnabled = false

        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)

        imageView.snp.makeConstraints { (make) in
            make.size.equalToSuperview()
            make.center.equalToSuperview()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func clear() {
        endTouch()
        imageView.image = nil
    }
    
    func endTouch() {
        currentTouch = nil
        lastPosition = nil
    }

    func updateTouch(touchPosition point: CGPoint) {
        let lastPositionOpt = self.lastPosition
        self.lastPosition = point

        let size = bounds.size

        UIGraphicsBeginImageContext(size)

        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return
        }

        if let image = imageView.image {
            image.draw(at: .zero)
        }

        context.setLineCap(.round)

        if let lastPosition = lastPositionOpt {
            context.move(to: lastPosition)
            context.addLine(to: point)
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(12)
            context.strokePath()
        }

        imageView.image = UIGraphicsGetImageFromCurrentImageContext()

        UIGraphicsEndImageContext()
    }
}

fileprivate class TrackOneTouchGestureRecognizer: UIGestureRecognizer {
    private(set) var touch: UITouch?
    
    override func location(in view: UIView?) -> CGPoint {
        return touch?.location(in: view) ?? CGPoint.zero
    }
    
    // By default, allow other recognizers to also receive the touch.
    lazy var canPreventFunc: (UIGestureRecognizer) -> Bool = { (recognizer: UIGestureRecognizer) -> Bool in
        return false
    }
    
    // MARK: UIGestureRecognizer
    
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        return canPreventFunc(preventedGestureRecognizer)
    }
    
    override func reset() {
        super.reset()
        
        touch = nil
        state = .possible
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if state == .possible {
            touch = touches.first!
            state = .began
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if let touch = touch, touches.contains(touch) {
            state = .changed
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        if let touch = touch, touches.contains(touch) {
            state = .ended
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        if let touch = touch, touches.contains(touch) {
            state = .cancelled
        }
    }
}
