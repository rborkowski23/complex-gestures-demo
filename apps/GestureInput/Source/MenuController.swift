import UIKit
import UIKit.UIGestureRecognizerSubclass

import RxCocoa
import RxDataSources
import RxSwift
import SnapKit

fileprivate struct SectionItem {
    var label: String
    var callback: (() -> Void)?
}

fileprivate struct Section {
    var items: [SectionItem]
}

extension Section: SectionModelType {
    typealias Item = SectionItem
    
    init(original: Section, items: [SectionItem]) {
        self = original
        self.items = items
    }
}

class Recognizer: UIGestureRecognizer {
    var maxMajorRadius: CGFloat = 0
    var startPosition: CGPoint = .zero
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        maxMajorRadius = touches.first!.majorRadius
        startPosition = touches.first!.location(in: view)
        
//        print("touchesBegan", /*touches, */touches.map { ($0.majorRadius, $0.majorRadiusTolerance) })
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        let newPosition = touches.first!.location(in: view)
        let diffX = startPosition.x - newPosition.x
        let diffY = startPosition.y - newPosition.y
        
        if diffX * diffX + diffY * diffY > 30 * 30 {
            print("Failed for went too far.")
            state = .failed
            return
        }
        
//        print("touchesMoved", /*touches, */touches.map { ($0.majorRadius, $0.majorRadiusTolerance) })
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        if maxMajorRadius > 40 {
            print("Recognized")
            state = .recognized
        }
        
        if state == .possible {
            print("Failed for not big enough.")
            state = .failed
        }
        
        print("maxMajorRadius", maxMajorRadius)
        
//        print("touchesEnded", /*touches, */touches.map { ($0.majorRadius, $0.majorRadiusTolerance) })
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
//        print("touchesCancelled", /*touches, */touches.map { $0.majorRadius })
    }
    
//    override func shouldRequireFailure(of otherGestureRecognizer: UIGestureRecognizer) -> Bool {
////        print("shouldRequireFailure", otherGestureRecognizer)
//        
//        return super.shouldRequireFailure(of: otherGestureRecognizer)
//    }
//    
//    override func shouldBeRequiredToFail(by otherGestureRecognizer: UIGestureRecognizer) -> Bool {
////        print("shouldBeRequiredToFail", otherGestureRecognizer, otherGestureRecognizer is UITapGestureRecognizer)
//        
//        return super.shouldBeRequiredToFail(by: otherGestureRecognizer)
//    }
    
    override func reset() {
        super.reset()
        
        print("reset")
        
        state = .possible
    }
    
//    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
////        print("canPrevent", preventedGestureRecognizer)
//        
//        return super.canPrevent(preventedGestureRecognizer)
//    }
    
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
//        print("canBePrevented", preventingGestureRecognizer)
        
        return false
        
//        return super.canBePrevented(by: preventingGestureRecognizer)
    }
    
    override func ignore(_ touch: UITouch, for event: UIEvent) {
        super.ignore(touch, for: event)
        
        print("ignore", touch)
    }
}

class MenuController: UINavigationController {
    var disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let _ = DataCache.shared.load()
        
        view.backgroundColor = UIColor.white
        
        let tableViewController = UITableViewController()
        tableViewController.title = "Gesture Input"
        pushViewController(tableViewController, animated: false)
        
        let tableView = tableViewController.tableView!
        
        tableView.dataSource = nil
        tableView.delegate = nil
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        
//        let recognizer = Recognizer()
//        tableView.addGestureRecognizer(recognizer)
        
        let dataSource = RxTableViewSectionedReloadDataSource<Section>()
        
        dataSource.configureCell = { dataSource, tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: .default, reuseIdentifier: "Cell")
            cell.textLabel?.text = item.label
            return cell
        }
        
        dataSource.titleForHeaderInSection = { dataSource, index in
            return nil
        }
        
        let data: [Section] = [
            Section(items: [
                SectionItem(label: "Add New Data") { [weak self] in
                    self?.pushViewController(InputViewController(), animated: true)
                },
                SectionItem(label: "Browse") { [weak self] in
                    self?.pushViewController(BrowseViewController(), animated: true)
                },
                SectionItem(label: "Rasterize") { [weak self] in
                    let _ = DataCache.shared.saveRasterized()
                    
                    let alert = UIAlertController(title: nil, message: "Done saving rasterized images file.", preferredStyle: .alert)
                    let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(action)
                    self?.present(alert, animated: true, completion: nil)
                }
            ])
        ]
        
        Observable<[Section]>.just(data)
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)
        
        let itemSelected = tableView.rx.itemSelected.asObservable()
        
        #if DEBUG
            // Uncomment to immediately show a particular page.
//            itemSelected = itemSelected.startWith(IndexPath(row: 1, section: 0))
        #endif
        
        itemSelected
            .subscribe(onNext: { indexPath in
                guard let callback = data[indexPath.section].items[indexPath.row].callback else {
                    return
                }
                
                callback()
            })
            .disposed(by: disposeBag)
    }
}
