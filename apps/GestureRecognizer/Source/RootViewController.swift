import UIKit

import RxSwift

extension GestureModel {
    static var shared = GestureModel()
}

class RootViewController: UIViewController {
    var disposeBag = DisposeBag()
    
    let complexGestureInput = ComplexGestureInput()
    
    @objc private func showInstructions() {
        let gestureList = GestureList()
        present(gestureList, animated: true, completion: nil)
    }
    
    // MARK: UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let canvas = UIView()
        view.addSubview(canvas)
        canvas.snp.makeConstraints { (make) in
            make.size.equalToSuperview()
            make.center.equalToSuperview()
        }
        
        complexGestureInput.view = canvas
        complexGestureInput.switchStatesOnFlatTap = false
        complexGestureInput.isGesturing.value = true
        
        let instructions = InstructionsView()
        instructions.button.addTarget(self, action: #selector(showInstructions), for: .touchUpInside)
        view.addSubview(instructions)
        
        instructions.snp.makeConstraints { (make) in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.topMargin).inset(20)
            make.centerX.equalToSuperview()
        }
        
        let notification = NotificationPopover()
        notification.isUserInteractionEnabled = false
        view.addSubview(notification)
        notification.makeSizeConstraints()
        notification.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().inset(30)
        }
        
        view.addSubview(complexGestureInput.previewView)
        complexGestureInput.previewView.snp.makeConstraints { (make) in
            make.size.equalToSuperview()
            make.center.equalToSuperview()
        }
        
        let drawingLabelValues = complexGestureInput
            .currentDrawing
            .filter({ $0.strokes.count > 0 })
            .distinctUntilChanged()
            .throttle(0.1, scheduler: MainScheduler.instance)
            .flatMap({ drawing -> Observable<(Drawing, [Double])> in
                guard let labelValues = predictLabel(drawing: drawing) else {
                    return Observable.empty()
                }
                
                print("labelValues", labelValues)
                
                return Observable.just((drawing, labelValues))
            })
            .share()
        
        let immediateRecognition: Observable<Touches_Label> =
            drawingLabelValues
                .flatMap { (drawing: Drawing, labelValues: [Double]) -> Observable<Touches_Label> in
                    // labelValues are the softmax outputs ("probabilities")
                    // for each label in Touches_Label.all, in the the order
                    // that they're present there.
                    
                    let max = labelValues.max()!
    
                    if max < 0.8 {
                        return Observable.empty()
                    }
    
                    let argMax = labelValues.index(where: { $0 == max })!
                    let prediction = Touches_Label.all[argMax]
                    
                    if drawing.strokes.count < requiredNumberOfStrokes(label: prediction) {
                        return Observable.empty()
                    }
                    
                    return Observable.just(prediction)
                }
        
        let delayedRecognition = immediateRecognition
            .flatMapLatest { label -> Observable<Touches_Label> in
                if shouldDelayRecognition(of: label) {
                    return Observable.just(label)
                        .delay(0.5, scheduler: MainScheduler.instance)
                }
                
                return Observable.just(label)
            }
        
        delayedRecognition
            .subscribe(onNext: { label in
                notification.show(label: label)
            })
            .disposed(by: disposeBag)
        
        let clearTimeout = Observable<Observable<Observable<()>>>.of(
                // Don't clear while the user is stroking.
                complexGestureInput
                    .didStartStroke
                    .map({ Observable.never() }),
                // After the user finishes a stroke, clear slowly (time out).
                complexGestureInput
                    .currentDrawing
                    .map({ _ in
                        Observable.just(())
                            .delay(1, scheduler: MainScheduler.instance)
                    }),
                // After the gesture is recognized, clear quickly unless the
                // user continues drawing.
                delayedRecognition
                    .map({ _ in
                        Observable.just(())
                            .delay(0.5, scheduler: MainScheduler.instance)
                    })
            )
            .merge()
            .flatMapLatest({ $0 })
        
        clearTimeout
            .subscribe(onNext: { [weak self] _ in
                self?.complexGestureInput.clear()
            })
            .disposed(by: disposeBag)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

fileprivate class InstructionsView: UIView {
    private let label = UILabel()
    let button = UIButton()
    
    init() {
        super.init(frame: .zero)
        
        label.isUserInteractionEnabled = false
        
        label.font = UIFont.systemFont(ofSize: 18)
        label.textColor = UIColor(white: 0.2, alpha: 1)
        label.textAlignment = .center
        label.text = "Make a gesture below."
        addSubview(label)
        label.snp.makeConstraints { (make) in
            make.top.equalToSuperview()
            make.left.equalToSuperview()
            make.right.equalToSuperview()
        }
        
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: UIFont.Weight.medium)
        button.titleLabel?.textAlignment = .center
        button.setTitleColor(UIColor("#37A0F4"), for: .normal)
        button.setTitle("See available gestures.", for: .normal)
        addSubview(button)
        button.snp.makeConstraints { (make) in
            make.top.equalTo(label.snp.bottom)
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
