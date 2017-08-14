import UIKit

import RxDataSources
import RxSwift
import SnapKit

class GestureList: UINavigationController, UITableViewDelegate {
    var disposeBag = DisposeBag()
    
    @objc private func done() {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tableViewController = UITableViewController()
        tableViewController.title = "Gestures"
        tableViewController.navigationItem.rightBarButtonItem =
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        pushViewController(tableViewController, animated: false)
        
        let tableView = tableViewController.tableView!
        tableView.allowsSelection = false
        tableView.register(ItemView.self, forCellReuseIdentifier: "Cell")
        
        let section = Section(items: [
                .checkmark,
                .xmark,
                .lineAscending,
                .scribble,
                .circle,
                .semicircleOpenUp,
                .heart,
                .plusSign,
                .questionMark,
                .letterACapital,
                .letterBCapital,
                .faceHappy,
                .faceSad
            ])
        
        let dataSource = RxTableViewSectionedReloadDataSource<Section>()
        
        dataSource.configureCell = { (dataSource, tableView, indexPath, item) in
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ItemView
            cell.label.text = item.name
            cell.imageContainer.image = item.image
            return cell
        }
        
        tableView.rx.setDelegate(self)
            .disposed(by: disposeBag)
        
        Observable.just([section])
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)
    }
    
    // MARK: UITableViewDelegate
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 75
    }
}

fileprivate struct Section {
    var items = [Touches_Label]()
}

extension Section: SectionModelType {
    init(original: Section, items: [Touches_Label]) {
        self = original
        self.items = items
    }
}

fileprivate class ItemView: UITableViewCell {
    let label = UILabel()
    let imageContainer = ColorEffectImageContainer(image: nil)
    
    override var isHighlighted: Bool {
        get {
            return false
        }
        set(newValue) {}
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        label.textColor = UIColor("#333333")
        label.font = UIFont.systemFont(ofSize: 20)
        contentView.addSubview(label)
        label.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().inset(30)
        }
        
        imageContainer.fillColor = UIColor("#333333")
        contentView.addSubview(imageContainer)
        imageContainer.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.centerX.equalTo(snp.right).inset(30 + 60/2)
            make.size.equalTo(CGSize(width: 60, height: 60))
        }
        imageContainer.centerImageView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
