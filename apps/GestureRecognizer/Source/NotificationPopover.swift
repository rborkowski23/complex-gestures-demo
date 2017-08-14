import UIKit

import RxSwift
import SnapKit

class NotificationPopover: UIView {
    private static let fadeDuration: Double = 0.2
    private static let timeBeforeFade: Double = 1.5
    
    var disposeBag = DisposeBag()
    
    var bottomLabel: UILabel!
    var imageView: UIImageView!
    
    private let showSubject = PublishSubject<Void>()
    
    init() {
        super.init(frame: .zero)
        
        isOpaque = false
        layer.opacity = 0
        isHidden = true
        
        backgroundColor = UIColor("#2196F3")
        layer.cornerRadius = 10
        
        let topLabel = UILabel()
        topLabel.text = "You drew:"
        topLabel.textColor = .white
        topLabel.textAlignment = .center
        topLabel.font = UIFont.systemFont(ofSize: 18)
        addSubview(topLabel)
        topLabel.snp.makeConstraints { (make) in
            make.top.equalToSuperview().inset(20)
            make.left.equalToSuperview().inset(20)
            make.right.equalToSuperview().inset(20)
        }
        
        bottomLabel = UILabel()
        bottomLabel.text = "Question mark"
        bottomLabel.textColor = .white
        bottomLabel.textAlignment = .center
        bottomLabel.font = UIFont.systemFont(ofSize: 22)
        bottomLabel.adjustsFontSizeToFitWidth = true
        addSubview(bottomLabel)
        bottomLabel.snp.makeConstraints { (make) in
            make.bottom.equalToSuperview().inset(25)
            make.left.equalToSuperview().inset(20)
            make.right.equalToSuperview().inset(20)
        }
        
        imageView = UIImageView()
        imageView.image = UIImage(named: "question_mark")!
        addSubview(imageView)
        imageView.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
        }
        
        showSubject
            .asObservable()
            .flatMapLatest { [weak self] _ -> Observable<Void> in
                guard let me = self else {
                    return Observable.empty()
                }
                
                return Observable.just(()).delay(type(of: me).timeBeforeFade, scheduler: MainScheduler.instance)
            }
            .subscribe(onNext: { [weak self] _ in
                guard let me = self else {
                    return
                }
                
                UIView.animate(withDuration: type(of: me).fadeDuration, animations: {
                        me.layer.opacity = 0
                    }, completion: { completed in
                        if completed {
                            me.isHidden = true
                        }
                    })
            })
            .disposed(by: disposeBag)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func makeSizeConstraints() {
        snp.makeConstraints { (make) in
            make.width.greaterThanOrEqualTo(200).priority(750)
            make.width.lessThanOrEqualTo(200).priority(250)
            make.height.greaterThanOrEqualTo(170).priority(750)
            make.height.lessThanOrEqualTo(170).priority(250)
        }
    }
    
    func show(label: Touches_Label) {
        bottomLabel.text = label.name
        imageView.image = label.image
        
        showSubject.onNext(())
        
        isHidden = false
        UIView.animate(withDuration: type(of: self).fadeDuration, animations: {
            self.layer.opacity = 1.0
        })
    }
}
