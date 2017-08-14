import UIKit

import RxCocoa
import RxSwift
import SnapKit

class BrowseViewController: UIViewController {
    var disposeBag = DisposeBag()
    
    private var imageView: UIImageView!
    
    private var currentIndex = Variable<Int?>(nil)
    private var currentDrawing: Observable<Drawing?> {
        return currentIndex
            .asObservable()
            .map({ (index: Int?) -> Drawing? in
                guard let index = index else {
                    return nil
                }
                
                let drawings = DataCache.shared.drawings
                
                if index < 0 || index >= drawings.count {
                    return nil
                }
                
                return drawings[index]
            })
    }
    private var currentLabel = Variable<Touches_Label?>(nil)
    
    init() {
        super.init(nibName: nil, bundle: nil)
        
        title = "Browse"
        
        navigationItem.backBarButtonItem = UIBarButtonItem(title: nil, style: .plain, target: self, action: #selector(closeMe))
        
        currentIndex
            .asObservable()
            .map({ (index: Int?) -> Touches_Label? in
                guard let index = index else {
                    return nil
                }
                
                let labels = DataCache.shared.labels
                
                if index < 0 || index >= labels.count {
                    return nil
                }
                
                return labels[index]
            })
            .bind(to: currentLabel)
            .disposed(by: disposeBag)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func closeMe() {
        navigationController?.popViewController(animated: true)
    }
    
    private func setIndex(_ index: Int) {
        let count = min(DataCache.shared.drawings.count, DataCache.shared.labels.count)
        
        if count == 0 {
            currentIndex.value = nil
            return
        }
        
        currentIndex.value = min(max(0, index), count - 1)
    }
    
    // MARK: UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let _ = DataCache.shared.load()
        setIndex(0)
        
        view.backgroundColor = UIColor.white
        
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)
        
        imageView.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.size.equalToSuperview()
        }
        
        currentDrawing
            .map { $0?.rasterized() }
            .bind(to: imageView.rx.image)
            .disposed(by: disposeBag)
        
        let indexControl = UIControl()
        view.addSubview(indexControl)
        
        indexControl.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.top.equalTo(topLayoutGuide.snp.bottom).offset(5)
        }
        
        indexControl.rx.controlEvent(.touchUpInside)
            .subscribe(onNext: { [weak self] in
                let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
                
                alert.addTextField(configurationHandler: { (textField) in
                    textField.text = String(self?.currentIndex.value ?? 0)
                })
                
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
                    guard let text = alert.textFields?.first?.text else {
                        return
                    }
                    
                    self?.setIndex(Int(text) ?? 0)
                }))
                
                self?.present(alert, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)
        
        let indexLabel = UILabel()
        indexControl.addSubview(indexLabel)
        
        indexLabel.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            // Inset here makes the indexControl bigger so that it's easier to tap.
            make.size.equalToSuperview().inset(5)
        }
        
        currentIndex
            .asObservable()
            .map { index -> String? in
                return index != nil ? String(index!) : nil
            }
            .bind(to: indexLabel.rx.text)
            .disposed(by: disposeBag)
        
        let classControl = UIControl()
        view.addSubview(classControl)
        
        classControl.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.top.equalTo(indexLabel.snp.bottom).offset(5)
        }
        
        classControl.rx.controlEvent(.touchUpInside)
            .subscribe(onNext: { [weak self] in
                guard let me = self else {
                    return
                }
                
                let controller = ClassPicker()
                controller.currentClass.value = me.currentLabel.value
                
                controller.didDismiss
                    .withLatestFrom(controller.currentClass.asObservable())
                    .subscribe(onNext: { [weak self] newClass in
                        guard let newClass = newClass, let currentIndex = self?.currentIndex.value else {
                            return
                        }
                        
                        DataCache.shared.labels[currentIndex] = newClass
                        // Trigger an update.
                        self?.currentIndex.value = self?.currentIndex.value
                    })
                    .disposed(by: me.disposeBag)
                
                me.present(controller, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)
        
        let classLabel = UILabel()
        classLabel.isUserInteractionEnabled = false
        classLabel.textColor = UIColor.black
        classControl.addSubview(classLabel)
        
        classLabel.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.size.equalToSuperview()
        }
        
        currentLabel
            .asObservable()
            .map { $0?.name }
            .bind(to: classLabel.rx.text)
            .disposed(by: disposeBag)
        
        let backButton = makeSimpleButton()
        backButton.setTitle("Back", for: .normal)
        view.addSubview(backButton)
        
        backButton.snp.makeConstraints { (make) in
            make.left.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(20)
        }
        
        backButton.rx.controlEvent(.touchUpInside)
            .subscribe(onNext: { [weak self] in
                guard let me = self else {
                    return
                }
                
                me.setIndex((me.currentIndex.value ?? 0) - 1)
            })
            .disposed(by: disposeBag)
        
        let nextButton = makeSimpleButton()
        nextButton.setTitle("Next", for: .normal)
        view.addSubview(nextButton)
        
        nextButton.snp.makeConstraints { (make) in
            make.right.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(20)
        }
        
        nextButton.rx.controlEvent(.touchUpInside)
            .subscribe(onNext: { [weak self] in
                guard let me = self else {
                    return
                }
                
                me.setIndex((me.currentIndex.value ?? 0) + 1)
            })
            .disposed(by: disposeBag)
        
        let saveButton = makeSimpleButton()
        saveButton.setTitle("Save Cache", for: .normal)
        view.addSubview(saveButton)
        
        saveButton.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().inset(20)
        }
        
        saveButton.rx.controlEvent(.touchUpInside)
            .subscribe(onNext: {
                let _ = DataCache.shared.save()
            })
            .disposed(by: disposeBag)
        
        let deleteButton = makeSimpleButton()
        deleteButton.setTitle("Delete", for: .normal)
        view.addSubview(deleteButton)
        
        deleteButton.snp.makeConstraints { (make) in
            make.right.equalToSuperview().inset(20)
            make.bottom.equalTo(saveButton.snp.top).offset(-20)
        }
        
        deleteButton.rx.controlEvent(.touchUpInside)
            .subscribe(onNext: { [weak self] in
                guard let me = self, let index = me.currentIndex.value else {
                    return
                }
                
                DataCache.shared.drawings.remove(at: index)
                DataCache.shared.labels.remove(at: index)
                
                me.setIndex(index)
            })
            .disposed(by: disposeBag)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        let _ = DataCache.shared.save()
    }
}

fileprivate class ClassPicker: UINavigationController, UIPickerViewDelegate, UIPickerViewDataSource {
    private(set) var disposeBag = DisposeBag()
    
    var currentClass = Variable<Touches_Label?>(nil)
    
    private var didDismissSubject = PublishSubject<Void>()
    var didDismiss: Observable<Void> {
        return didDismissSubject.asObservable()
    }
    
    @objc private func doneTapped() {
        dismiss(animated: true, completion: nil)
        didDismissSubject.onNext(())
    }
    
    // MARK: UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let innerController = UIViewController()
        innerController.title = "Set Label"
        
        innerController.view.backgroundColor = UIColor.white
        
        innerController.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneTapped))
        
        let picker = UIPickerView()
        picker.delegate = self
        picker.dataSource = self
        innerController.view.addSubview(picker)
        
        picker.snp.makeConstraints { (make) in
            make.top.equalTo(innerController.topLayoutGuide.snp.bottom)
            make.width.equalToSuperview()
            make.height.equalTo(200)
        }
        
        currentClass
            .asObservable()
            .distinctUntilChanged(==)
            .subscribe(onNext: { currentClass in
                guard let currentClass = currentClass, let index = Touches_Label.all.index(of: currentClass) else {
                    return
                }
                
                picker.selectRow(index, inComponent: 0, animated: false)
            })
            .disposed(by: disposeBag)
        
        picker.rx.itemSelected
            .map { (row, _) in Touches_Label.all[row] }
            .bind(to: currentClass)
            .disposed(by: disposeBag)
        
        pushViewController(innerController, animated: false)
    }
    
    // MARK: UIPickerViewDelegate
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return Touches_Label.all[row].name
    }
    
    // MARK: UIPickerViewDataSource
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return Touches_Label.all.count
    }
}
