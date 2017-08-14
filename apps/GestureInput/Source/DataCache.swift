import UIKit

fileprivate let dataFileName = "data.dataset"
fileprivate let rasterizedFileName = "data.trainingset"

class DataCache {
    static let shared = DataCache()
    
    var drawings = [Drawing]()
    var labels = [Touches_Label]()
    
    func load() -> Bool {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
        let url = documentsURL.appendingPathComponent(dataFileName)
        
        guard let data = try? Data(contentsOf: url) else {
            return false
        }
        
        guard let dataSet = try? Touches_RawDataSet(serializedData: data) else {
            return false
        }
        
        drawings = dataSet.drawingList.drawings.map { Drawing(touchesDrawing: $0) }
        labels = dataSet.labels
        
        return true
    }
    
    func save() -> Bool {
        var drawingList = Touches_DrawingList()
        drawingList.drawings = self.drawings.map { $0.touchesDrawing }
        
        var dataSet = Touches_RawDataSet()
        dataSet.drawingList = drawingList
        dataSet.labels = labels
        
        guard let data = try? dataSet.serializedData() else {
            return false
        }
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
        let url = documentsURL.appendingPathComponent(dataFileName)

        if (try? data.write(to: url)) == nil {
            return false
        }
    
        return true
    }
    
    func saveRasterized() -> Bool {
        var trainingSet = Touches_TrainingSet()
        
        let count = min(drawings.count, labels.count)
        for i in 0 ..< count {
            let drawing = drawings[i]
            let label = labels[i]
            
            guard let image = drawing.touchesImage else {
                continue
            }
            
            var labelledImage = Touches_LabelledImage()
            labelledImage.image = image
            labelledImage.label = label
            
            trainingSet.labelledImages.append(labelledImage)
            
            let numDone = i + 1
            if numDone % 50 == 0 || numDone == count {
                print("Done generating \(numDone)/\(count) images.")
            }
        }
        
        guard let data = try? trainingSet.serializedData() else {
            return false
        }
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
        let url = documentsURL.appendingPathComponent(rasterizedFileName)
        
        if (try? data.write(to: url)) == nil {
            return false
        }
        
        return true
    }
}
