import numpy as np
import protobuf.mlmodel_specification.Model_pb2 as mlmodel
import tensorflow as tf

from .constants import *


def tf_conv_weights_order_to_mlmodel(array):
    array = np.swapaxes(array, 3, 0)
    array = np.swapaxes(array, 2, 1)
    array = np.swapaxes(array, 2, 3)
    return array


def tf_fc_weights_order_to_mlmodel(array):
    return np.swapaxes(array, 0, 1)


def make_network(x):
    """Create the graph for the neural network, minus the softmax layer.

    Don't forget to keep this in sync with save_mlmodel below.
    """
    vars = {}

    # Grayscale image
    x_image = tf.reshape(x, [-1, IMAGE_HEIGHT, IMAGE_WIDTH, 1])

    # First convolutional layer
    vars['W_conv1'] = weight_variable([3, 3, 1, 32])
    vars['b_conv1'] = bias_variable([32])

    h_conv1 = tf.nn.relu(conv2d(x_image, vars['W_conv1']) + vars['b_conv1'])

    # First pooling layer
    h_pool1 = max_pool_2x2(h_conv1)

    # Second convolutional layer
    vars['W_conv2'] = weight_variable([3, 3, 32, 64])
    vars['b_conv2'] = bias_variable([64])
    h_conv2 = tf.nn.relu(conv2d(h_pool1, vars['W_conv2']) + vars['b_conv2'])

    # Second pooling layer
    h_pool2 = max_pool_2x2(h_conv2)

    # Third convolutional layer
    vars['W_conv3'] = weight_variable([3, 3, 64, 64])
    vars['b_conv3'] = bias_variable([64])
    h_conv3 = tf.nn.relu(conv2d(h_pool2, vars['W_conv3']) + vars['b_conv3'])

    # Third pooling layer
    h_pool3 = max_pool_2x2(h_conv3)

    # Fully connected layer 1
    vars['W_fc1'] = weight_variable([6 * 6 * 64, 1024])
    vars['b_fc1'] = bias_variable([1024])

    h_pool3_flat = tf.reshape(h_pool3, [-1, 6*6*64])
    h_fc1 = tf.nn.relu(tf.matmul(h_pool3_flat, vars['W_fc1']) + vars['b_fc1'])

    # Dropout layer
    vars['keep_prob'] = tf.placeholder(tf.float32)
    h_fc1_drop = tf.nn.dropout(h_fc1, vars['keep_prob'])

    # Fully connected layer 2
    vars['W_fc2'] = weight_variable([1024, NUM_LABEL_INDEXES])
    vars['b_fc2'] = bias_variable([NUM_LABEL_INDEXES])

    output = tf.matmul(h_fc1_drop, vars['W_fc2']) + vars['b_fc2']

    # NOTE: The softmax layer is not included here.

    return output, vars


def conv2d(x, W):
    """conv2d returns a 2d convolution layer with full stride."""
    return tf.nn.conv2d(x, W, strides=[1, 1, 1, 1], padding='SAME')


def max_pool_2x2(x):
    """max_pool_2x2 downsamples a feature map by 2X."""
    return tf.nn.max_pool(x, ksize=[1, 2, 2, 1],
        strides=[1, 2, 2, 1], padding='SAME')


def weight_variable(shape):
    """weight_variable generates a weight variable of a given shape."""
    initial = tf.truncated_normal(shape, stddev=0.1)
    return tf.Variable(initial)


def bias_variable(shape):
    """bias_variable generates a bias variable of a given shape."""
    initial = tf.constant(0.1, shape=shape)
    return tf.Variable(initial)


def save_mlmodel(file_name, variables):
    model = mlmodel.Model()
    model.specificationVersion = 1

    model_description = model.description

    input_description = mlmodel.FeatureDescription()
    input_description.name = 'image'
    input_description.shortDescription = 'An image to recognize'
    input_description.type.isOptional = False

    input_description.type.multiArrayType.shape.extend([1, IMAGE_HEIGHT, IMAGE_WIDTH])
    input_description.type.multiArrayType.dataType = mlmodel.ArrayFeatureType.ArrayDataType.Value('FLOAT32')

    model_description.input.extend([input_description])

    output_description = mlmodel.FeatureDescription()
    output_description.name = 'labelValues'
    output_description.shortDescription = 'For each possible label, the "probability" of that label in the index of the label\'s enum value.'
    output_description.type.isOptional = False
    output_description.type.multiArrayType.shape.extend([NUM_LABEL_INDEXES])
    output_description.type.multiArrayType.dataType = mlmodel.ArrayFeatureType.ArrayDataType.Value('FLOAT32')
    model_description.output.extend([output_description])

    model_description.predictedFeatureName = 'labelValues'
    model_description.predictedProbabilitiesName = 'labelValues'

    metadata = model_description.metadata
    metadata.shortDescription = 'Model for recognizing a variety of images drawn on screen with one\'s finger'

    neural_network = model.neuralNetwork
    layers = neural_network.layers

    add_layer = mlmodel.NeuralNetworkLayer()
    add_layer.name = 'Make values go from -0.5 to 0.5.'
    add_layer.input.extend(['image'])
    add_layer.output.extend(['add_layer'])
    add_layer.add.alpha = -0.5
    layers.extend([add_layer])

    conv2d_1 = mlmodel.NeuralNetworkLayer()
    conv2d_1.name = 'First convolution'
    conv2d_1.input.extend(['add_layer'])
    conv2d_1.output.extend(['conv2d_1'])
    conv2d_1.convolution.outputChannels = 32
    conv2d_1.convolution.kernelChannels = 1
    conv2d_1.convolution.kernelSize.extend([3, 3])
    conv2d_1.convolution.same.asymmetryMode = mlmodel.SamePadding.SamePaddingMode.Value('BOTTOM_RIGHT_HEAVY')
    conv2d_1.convolution.isDeconvolution = False
    conv2d_1.convolution.hasBias = True
    conv2d_1.convolution.weights.floatValue.extend(tf_conv_weights_order_to_mlmodel(variables['W_conv1'].eval()).flatten())
    conv2d_1.convolution.bias.floatValue.extend(variables['b_conv1'].eval().flatten())
    layers.extend([conv2d_1])

    relu_1 = mlmodel.NeuralNetworkLayer()
    relu_1.name = 'First relu'
    relu_1.input.extend(['conv2d_1'])
    relu_1.output.extend(['relu_1'])
    relu_1.activation.ReLU.SetInParent()
    layers.extend([relu_1])

    maxpool_1 = mlmodel.NeuralNetworkLayer()
    maxpool_1.name = 'First maxpool'
    maxpool_1.input.extend(['relu_1'])
    maxpool_1.output.extend(['maxpool_1'])
    maxpool_1.pooling.type = mlmodel.PoolingLayerParams.PoolingType.Value('MAX')
    maxpool_1.pooling.kernelSize.extend([2, 2])
    maxpool_1.pooling.stride.extend([2, 2])
    maxpool_1.pooling.same.asymmetryMode = mlmodel.SamePadding.SamePaddingMode.Value('BOTTOM_RIGHT_HEAVY')
    layers.extend([maxpool_1])

    conv2d_2 = mlmodel.NeuralNetworkLayer()
    conv2d_2.name = 'Second convolution'
    conv2d_2.input.extend(['maxpool_1'])
    conv2d_2.output.extend(['conv2d_2'])
    conv2d_2.convolution.outputChannels = 64
    conv2d_2.convolution.kernelChannels = 32
    conv2d_2.convolution.kernelSize.extend([3, 3])
    conv2d_2.convolution.same.asymmetryMode = mlmodel.SamePadding.SamePaddingMode.Value('BOTTOM_RIGHT_HEAVY')
    conv2d_2.convolution.isDeconvolution = False
    conv2d_2.convolution.hasBias = True
    conv2d_2.convolution.weights.floatValue.extend(tf_conv_weights_order_to_mlmodel(variables['W_conv2'].eval()).flatten())
    conv2d_2.convolution.bias.floatValue.extend(variables['b_conv2'].eval().flatten())
    layers.extend([conv2d_2])

    relu_2 = mlmodel.NeuralNetworkLayer()
    relu_2.name = 'Second relu'
    relu_2.input.extend(['conv2d_2'])
    relu_2.output.extend(['relu_2'])
    relu_2.activation.ReLU.SetInParent()
    layers.extend([relu_2])

    maxpool_2 = mlmodel.NeuralNetworkLayer()
    maxpool_2.name = 'Second maxpool'
    maxpool_2.input.extend(['relu_2'])
    maxpool_2.output.extend(['maxpool_2'])
    maxpool_2.pooling.type = mlmodel.PoolingLayerParams.PoolingType.Value('MAX')
    maxpool_2.pooling.kernelSize.extend([2, 2])
    maxpool_2.pooling.stride.extend([2, 2])
    maxpool_2.pooling.same.asymmetryMode = mlmodel.SamePadding.SamePaddingMode.Value('BOTTOM_RIGHT_HEAVY')
    layers.extend([maxpool_2])

    conv2d_3 = mlmodel.NeuralNetworkLayer()
    conv2d_3.name = 'Third convolution'
    conv2d_3.input.extend(['maxpool_2'])
    conv2d_3.output.extend(['conv2d_3'])
    conv2d_3.convolution.outputChannels = 64
    conv2d_3.convolution.kernelChannels = 64
    conv2d_3.convolution.kernelSize.extend([3, 3])
    conv2d_3.convolution.same.asymmetryMode = mlmodel.SamePadding.SamePaddingMode.Value('BOTTOM_RIGHT_HEAVY')
    conv2d_3.convolution.isDeconvolution = False
    conv2d_3.convolution.hasBias = True
    conv2d_3.convolution.weights.floatValue.extend(tf_conv_weights_order_to_mlmodel(variables['W_conv3'].eval()).flatten())
    conv2d_3.convolution.bias.floatValue.extend(variables['b_conv3'].eval().flatten())
    layers.extend([conv2d_3])

    relu_3 = mlmodel.NeuralNetworkLayer()
    relu_3.name = 'Third relu'
    relu_3.input.extend(['conv2d_3'])
    relu_3.output.extend(['relu_3'])
    relu_3.activation.ReLU.SetInParent()
    layers.extend([relu_3])

    maxpool_3 = mlmodel.NeuralNetworkLayer()
    maxpool_3.name = 'Third maxpool'
    maxpool_3.input.extend(['relu_3'])
    maxpool_3.output.extend(['maxpool_3'])
    maxpool_3.pooling.type = mlmodel.PoolingLayerParams.PoolingType.Value('MAX')
    maxpool_3.pooling.kernelSize.extend([2, 2])
    maxpool_3.pooling.stride.extend([2, 2])
    maxpool_3.pooling.same.asymmetryMode = mlmodel.SamePadding.SamePaddingMode.Value('BOTTOM_RIGHT_HEAVY')
    layers.extend([maxpool_3])

    maxpool_3_flat = mlmodel.NeuralNetworkLayer()
    maxpool_3_flat.name = 'Flatten'
    maxpool_3_flat.input.extend(['maxpool_3'])
    maxpool_3_flat.output.extend(['maxpool_3_flat'])
    maxpool_3_flat.flatten.mode = mlmodel.FlattenLayerParams.FlattenOrder.Value('CHANNEL_LAST')
    layers.extend([maxpool_3_flat])

    fc1 = mlmodel.NeuralNetworkLayer()
    fc1.name = 'First fully-connected layer'
    fc1.input.extend(['maxpool_3_flat'])
    fc1.output.extend(['fc1'])
    fc1.innerProduct.inputChannels = 6*6*64
    fc1.innerProduct.outputChannels = 1024
    fc1.innerProduct.hasBias = True
    fc1.innerProduct.weights.floatValue.extend(tf_fc_weights_order_to_mlmodel(variables['W_fc1'].eval()).flatten())
    fc1.innerProduct.bias.floatValue.extend(variables['b_fc1'].eval().flatten())
    layers.extend([fc1])

    relu_4 = mlmodel.NeuralNetworkLayer()
    relu_4.name = 'Fourth relu'
    relu_4.input.extend(['fc1'])
    relu_4.output.extend(['relu_4'])
    relu_4.activation.ReLU.SetInParent()
    layers.extend([relu_4])

    fc2 = mlmodel.NeuralNetworkLayer()
    fc2.name = 'Second fully-connected layer'
    fc2.input.extend(['relu_4'])
    fc2.output.extend(['fc2'])
    fc2.innerProduct.inputChannels = 1024
    fc2.innerProduct.outputChannels = NUM_LABEL_INDEXES
    fc2.innerProduct.hasBias = True
    fc2.innerProduct.weights.floatValue.extend(tf_fc_weights_order_to_mlmodel(variables['W_fc2'].eval()).flatten())
    fc2.innerProduct.bias.floatValue.extend(variables['b_fc2'].eval().flatten())
    layers.extend([fc2])

    sm = mlmodel.NeuralNetworkLayer()
    sm.name = 'Softmax layer'
    sm.input.extend(['fc2'])
    sm.output.extend(['labelValues'])
    sm.softmax.SetInParent()
    layers.extend([sm])

    f = open(file_name, 'wb')
    f.write(model.SerializeToString())
    f.close()

    print('Saved to file: %s' % file_name)
