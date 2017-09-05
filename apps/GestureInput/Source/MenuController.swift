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
