import CoreML

/**
 * Return whether a recognized label should be immediately used or delayed.
 *
 * We delay recognition when a drawing may be a subset of another drawing that
 * the user is actually trying to draw. That gives the user time to complete the
 * drawing.
 */
func shouldDelayRecognition(of label: Touches_Label) -> Bool {
    switch label {
    case .lineAscending:
        // Allow x marks to be recognized.
        return true
    case .semicircleOpenUp:
        // In case user draws the mouth of a happy face before the eyes.
        return true
    default:
        return false
    }
}

func requiredNumberOfStrokes(label: Touches_Label) -> Int {
    switch label {
    case .xmark:
        return 2
    case .plusSign:
        return 2
    case .faceHappy:
        return 3
    case .faceSad:
        return 3
    default:
        return 1
    }
}

/**
 * Convert the `Drawing` into a binary image and use a neural network to compute
 * values ("probabilities") for each gesture label.
 *
 * - returns: An array that has at each index `i` the value for
 * `Touches_Label.all[i]`. We do not use the raw values of the labels as indexes
 * in the label vector of the neural network because that would result in a much
 * longer array.
 */
func predictLabel(drawing: Drawing) -> [Double]? {
    let overallStartTime = Date()
    
    let imageStartTime = Date()
    guard let array = drawingToGestureModelFormat(drawing) else {
        return nil
    }
    let timeToGenerateImage = Date().timeIntervalSince(imageStartTime)
    
    let model = GestureModel.shared
    
    let predictionStartTime = Date()
    guard let labelValues = try? model.prediction(image: array).labelValues else {
        return nil
    }
    let timeToMakePrediction = Date().timeIntervalSince(predictionStartTime)
    
    let overallTime = Date().timeIntervalSince(overallStartTime)
    print("timeToGenerateImage=\(timeToGenerateImage) timeToMakePrediction=\(timeToMakePrediction) overallTime=\(overallTime)")
    
    let dataPointer = labelValues.dataPointer.bindMemory(to: Double.self, capacity: labelValues.count)
    return Array(UnsafeBufferPointer(start: dataPointer, count: labelValues.count))
}

/**
 * Convert the `Drawing` into a binary image of format suitable for input to the
 * GestureModel neural network.
 *
 * - returns: If successful, a valid input for GestureModel
 */
func drawingToGestureModelFormat(_ drawing: Drawing) -> MLMultiArray? {
    guard let image = drawing.rasterized(), let grays = imageToGrayscaleValues(image: image) else {
        return nil
    }
    
    guard let array = try? MLMultiArray(
        shape: [
            1,
            NSNumber(integerLiteral: Int(image.size.width)),
            NSNumber(integerLiteral: Int(image.size.height))
        ],
        dataType: .float32
        ) else {
            return nil
    }
    
    let floatArray = array.dataPointer.bindMemory(to: Float32.self, capacity: array.count)
    
    for i in 0 ..< array.count {
        floatArray.advanced(by: i).pointee = Float32(Double(grays[i]) / 255.0)
    }
    
    return array
}
