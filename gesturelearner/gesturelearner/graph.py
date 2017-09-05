from coremltools.models import MLModel
from coremltools.models.neural_network import NeuralNetworkBuilder
from coremltools.models.utils import save_spec
import coremltools.models.datatypes as datatypes
import coremltools.proto.Model_pb2 as mlmodel
import numpy as np
import tensorflow as tf

from .constants import *


def tf_conv_weights_order_to_mlmodel(array):
    """From (height, width, inputChannels, outputChannels) to (outputChannels, inputChannels, height, width)

    This is not the same as simply reshaping! Moving axes changes the order in which the values appear in memory.
    """
    array = np.swapaxes(array, 3, 0)
    array = np.swapaxes(array, 2, 1)
    array = np.swapaxes(array, 2, 3)
    return array


def tf_fc_weights_order_to_mlmodel(array):
    """From (inputChannels, outputChannels) to (outputChannels, inputChannels)

    This is not the same as simply reshaping! Moving axes changes the order in which the values appear in memory.
    """
    return np.swapaxes(array, 0, 1)


def make_network(input):
    """Create the graph for the neural network, minus the softmax layer.

    For this project, this graph should be kept in sync with make_mlmodel and save_mlmodel_using_protobuf below.
    Readers using this as a reference should probably ignore save_mlmodel_using_protobuf and just use make_mlmodel (use
    coremltools rather than directly using the MLModel protobuf specification).
    """
    vars = {}

    # Grayscale image
    x_image = tf.reshape(input, [-1, IMAGE_HEIGHT, IMAGE_WIDTH, 1])

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


def make_mlmodel(variables):
    # Specify the inputs and outputs (there can be multiple).
    # Each name corresponds to the input_name/output_name of a layer in the network so
    # that Core ML knows where to insert and extract data.
    input_features = [('image', datatypes.Array(1, IMAGE_HEIGHT, IMAGE_WIDTH))]
    output_features = [('labelValues', datatypes.Array(NUM_LABEL_INDEXES))]
    builder = NeuralNetworkBuilder(input_features, output_features, mode=None)

    # The "name" parameter has no effect on the function of the network. As far as I know
    # it's only used when Xcode fails to load your mlmodel and gives you an error telling
    # you what the problem is.
    # The input_names and output_name are used to link layers to each other and to the
    # inputs and outputs of the model. When adding or removing layers, or renaming their
    # outputs, always make sure you correct the input and output names of the layers
    # before and after them.
    builder.add_elementwise(name='add_layer',
                            input_names=['image'], output_name='add_layer', mode='ADD',
                            alpha=-0.5)

    # Although Core ML internally uses weight matrices of shape
    # (outputChannels, inputChannels, height, width) (as can be found by looking at the
    # protobuf specification comments), add_convolution takes the shape
    # (height, width, inputChannels, outputChannels) (as can be found in the coremltools
    # documentation). The latter shape matches what TensorFlow uses so we don't need to
    # reorder the matrix axes ourselves.
    builder.add_convolution(name='conv2d_1', kernel_channels=1,
                            output_channels=32, height=3, width=3, stride_height=1,
                            stride_width=1, border_mode='same', groups=0,
                            W=variables['W_conv1'].eval(), b=variables['b_conv1'].eval(),
                            has_bias=True, is_deconv=False, output_shape=None,
                            input_name='add_layer', output_name='conv2d_1')

    builder.add_activation(name='relu_1', non_linearity='RELU', input_name='conv2d_1',
                           output_name='relu_1', params=None)

    builder.add_pooling(name='maxpool_1', height=2, width=2, stride_height=2,
                        stride_width=2, layer_type='MAX', padding_type='SAME',
                        input_name='relu_1', output_name='maxpool_1')

    builder.add_convolution(name='conv2d_2', kernel_channels=32,
                            output_channels=64, height=3, width=3, stride_height=1,
                            stride_width=1, border_mode='same', groups=0,
                            W=variables['W_conv2'].eval(), b=variables['b_conv2'].eval(),
                            has_bias=True, is_deconv=False, output_shape=None,
                            input_name='maxpool_1', output_name='conv2d_2')

    builder.add_activation(name='relu_2', non_linearity='RELU',
                           input_name='conv2d_2', output_name='relu_2', params=None)

    builder.add_pooling(name='maxpool_2', height=2, width=2, stride_height=2,
                        stride_width=2, layer_type='MAX', padding_type='SAME',
                        input_name='relu_2', output_name='maxpool_2')

    builder.add_convolution(name='conv2d_3', kernel_channels=64,
                            output_channels=64, height=3, width=3, stride_height=1,
                            stride_width=1, border_mode='same', groups=0,
                            W=variables['W_conv3'].eval(), b=variables['b_conv3'].eval(),
                            has_bias=True, is_deconv=False, output_shape=None,
                            input_name='maxpool_2', output_name='conv2d_3')

    builder.add_activation(name='relu_3', non_linearity='RELU', input_name='conv2d_3',
                           output_name='relu_3', params=None)

    builder.add_pooling(name='maxpool_3', height=2, width=2, stride_height=2,
                        stride_width=2, layer_type='MAX', padding_type='SAME',
                        input_name='relu_3', output_name='maxpool_3')

    builder.add_flatten(name='maxpool_3_flat', mode=1, input_name='maxpool_3',
                        output_name='maxpool_3_flat')

    # We must swap the axes of the weight matrix because add_inner_product takes the shape
    # (outputChannels, inputChannels) whereas TensorFlow uses
    # (inputChannels, outputChannels). Unlike with add_convolution (see the comment
    # above), the shape add_inner_product expects matches what the protobuf specification
    # requires for inner products.
    builder.add_inner_product(name='fc1',
                              W=tf_fc_weights_order_to_mlmodel(variables['W_fc1'].eval())
                                .flatten(),
                              b=variables['b_fc1'].eval().flatten(),
                              input_channels=6*6*64, output_channels=1024, has_bias=True,
                              input_name='maxpool_3_flat', output_name='fc1')

    builder.add_activation(name='relu_4', non_linearity='RELU', input_name='fc1',
                           output_name='relu_4', params=None)

    builder.add_inner_product(name='fc2',
                              W=tf_fc_weights_order_to_mlmodel(variables['W_fc2'].eval())
                                .flatten(),
                              b=variables['b_fc2'].eval().flatten(), input_channels=1024,
                              output_channels=NUM_LABEL_INDEXES, has_bias=True,
                              input_name='relu_4', output_name='fc2')

    builder.add_softmax(name='softmax', input_name='fc2', output_name='labelValues')

    model = MLModel(builder.spec)

    model.short_description = 'Model for recognizing a variety of images drawn on screen with one\'s finger'

    model.input_description['image'] = 'A gesture image to classify'
    model.output_description['labelValues'] = 'The "probability" of each label, in a dense array'

    return model


def save_mlmodel(file_name, variables):
    model = make_mlmodel(variables)
    model.save(file_name)

    print('Saved to file: %s' % file_name)


def save_mlmodel_using_protobuf(file_name, variables):
    model = mlmodel.Model()
    model.specificationVersion = 1

    model_description = model.description

    input_description = mlmodel.FeatureDescription()
    input_description.name = 'image'
    input_description.shortDescription = 'A gesture image to classify'
    input_description.type.isOptional = False

    input_description.type.multiArrayType.shape.extend([1, IMAGE_HEIGHT, IMAGE_WIDTH])
    input_description.type.multiArrayType.dataType = mlmodel.ArrayFeatureType.ArrayDataType.Value('DOUBLE')

    model_description.input.extend([input_description])

    output_description = mlmodel.FeatureDescription()
    output_description.name = 'labelValues'
    output_description.shortDescription = 'The "probability" of each label, in a dense array'
    output_description.type.isOptional = False
    output_description.type.multiArrayType.shape.extend([NUM_LABEL_INDEXES])
    output_description.type.multiArrayType.dataType = mlmodel.ArrayFeatureType.ArrayDataType.Value('DOUBLE')
    model_description.output.extend([output_description])

    model_description.predictedFeatureName = 'labelValues'
    model_description.predictedProbabilitiesName = 'labelValues'

    metadata = model_description.metadata
    metadata.shortDescription = 'Model for recognizing a variety of images drawn on screen with one\'s finger'

    neural_network = model.neuralNetwork
    layers = neural_network.layers

    add_layer = mlmodel.NeuralNetworkLayer()
    add_layer.name = 'add_layer'
    add_layer.input.extend(['image'])
    add_layer.output.extend(['add_layer'])
    add_layer.add.alpha = -0.5
    layers.extend([add_layer])

    conv2d_1 = mlmodel.NeuralNetworkLayer()
    conv2d_1.name = 'conv2d_1'
    conv2d_1.input.extend(['add_layer'])
    conv2d_1.output.extend(['conv2d_1'])
    conv2d_1.convolution.outputChannels = 32
    conv2d_1.convolution.kernelChannels = 1
    conv2d_1.convolution.kernelSize.extend([3, 3])
    conv2d_1.convolution.same.asymmetryMode = mlmodel.SamePadding.SamePaddingMode.Value('BOTTOM_RIGHT_HEAVY')
    conv2d_1.convolution.isDeconvolution = False
    conv2d_1.convolution.hasBias = True
    # We must reorder the weight matrix axes because Core ML internally uses the shape
    # (outputChannels, inputChannels, height, width) but TensorFlow uses (height, width, inputChannels, outputChannels).
    # On the contrary, when using the coremltools instead of using protobuf directly, there is no need to do this reshaping.
    # coremltools takes the same shape as TensorFlow and seems to reorder the matrix axes for you. See the comments in
    # make_mlmodel above for more explanation.
    conv2d_1.convolution.weights.floatValue.extend(tf_conv_weights_order_to_mlmodel(variables['W_conv1'].eval()).flatten())
    conv2d_1.convolution.bias.floatValue.extend(variables['b_conv1'].eval().flatten())
    layers.extend([conv2d_1])

    relu_1 = mlmodel.NeuralNetworkLayer()
    relu_1.name = 'relu_1'
    relu_1.input.extend(['conv2d_1'])
    relu_1.output.extend(['relu_1'])
    relu_1.activation.ReLU.SetInParent()
    layers.extend([relu_1])

    maxpool_1 = mlmodel.NeuralNetworkLayer()
    maxpool_1.name = 'maxpool_1'
    maxpool_1.input.extend(['relu_1'])
    maxpool_1.output.extend(['maxpool_1'])
    maxpool_1.pooling.type = mlmodel.PoolingLayerParams.PoolingType.Value('MAX')
    maxpool_1.pooling.kernelSize.extend([2, 2])
    maxpool_1.pooling.stride.extend([2, 2])
    maxpool_1.pooling.same.asymmetryMode = mlmodel.SamePadding.SamePaddingMode.Value('BOTTOM_RIGHT_HEAVY')
    layers.extend([maxpool_1])

    conv2d_2 = mlmodel.NeuralNetworkLayer()
    conv2d_2.name = 'conv2d_2'
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
    relu_2.name = 'relu_2'
    relu_2.input.extend(['conv2d_2'])
    relu_2.output.extend(['relu_2'])
    relu_2.activation.ReLU.SetInParent()
    layers.extend([relu_2])

    maxpool_2 = mlmodel.NeuralNetworkLayer()
    maxpool_2.name = 'maxpool_2'
    maxpool_2.input.extend(['relu_2'])
    maxpool_2.output.extend(['maxpool_2'])
    maxpool_2.pooling.type = mlmodel.PoolingLayerParams.PoolingType.Value('MAX')
    maxpool_2.pooling.kernelSize.extend([2, 2])
    maxpool_2.pooling.stride.extend([2, 2])
    maxpool_2.pooling.same.asymmetryMode = mlmodel.SamePadding.SamePaddingMode.Value('BOTTOM_RIGHT_HEAVY')
    layers.extend([maxpool_2])

    conv2d_3 = mlmodel.NeuralNetworkLayer()
    conv2d_3.name = 'conv2d_3'
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
    relu_3.name = 'relu_3'
    relu_3.input.extend(['conv2d_3'])
    relu_3.output.extend(['relu_3'])
    relu_3.activation.ReLU.SetInParent()
    layers.extend([relu_3])

    maxpool_3 = mlmodel.NeuralNetworkLayer()
    maxpool_3.name = 'maxpool_3'
    maxpool_3.input.extend(['relu_3'])
    maxpool_3.output.extend(['maxpool_3'])
    maxpool_3.pooling.type = mlmodel.PoolingLayerParams.PoolingType.Value('MAX')
    maxpool_3.pooling.kernelSize.extend([2, 2])
    maxpool_3.pooling.stride.extend([2, 2])
    maxpool_3.pooling.same.asymmetryMode = mlmodel.SamePadding.SamePaddingMode.Value('BOTTOM_RIGHT_HEAVY')
    layers.extend([maxpool_3])

    maxpool_3_flat = mlmodel.NeuralNetworkLayer()
    maxpool_3_flat.name = 'maxpool_3_flat'
    maxpool_3_flat.input.extend(['maxpool_3'])
    maxpool_3_flat.output.extend(['maxpool_3_flat'])
    maxpool_3_flat.flatten.mode = mlmodel.FlattenLayerParams.FlattenOrder.Value('CHANNEL_LAST')
    layers.extend([maxpool_3_flat])

    fc1 = mlmodel.NeuralNetworkLayer()
    fc1.name = 'fc1'
    fc1.input.extend(['maxpool_3_flat'])
    fc1.output.extend(['fc1'])
    fc1.innerProduct.inputChannels = 6*6*64
    fc1.innerProduct.outputChannels = 1024
    fc1.innerProduct.hasBias = True
    # We must reorder the weight matrix axes because Core ML uses the shape (outputChannels, inputChannels) but
    # TensorFlow uses the shape (inputChannels, outputChannels).
    fc1.innerProduct.weights.floatValue.extend(tf_fc_weights_order_to_mlmodel(variables['W_fc1'].eval()).flatten())
    fc1.innerProduct.bias.floatValue.extend(variables['b_fc1'].eval().flatten())
    layers.extend([fc1])

    relu_4 = mlmodel.NeuralNetworkLayer()
    relu_4.name = 'relu_4'
    relu_4.input.extend(['fc1'])
    relu_4.output.extend(['relu_4'])
    relu_4.activation.ReLU.SetInParent()
    layers.extend([relu_4])

    fc2 = mlmodel.NeuralNetworkLayer()
    fc2.name = 'fc2'
    fc2.input.extend(['relu_4'])
    fc2.output.extend(['fc2'])
    fc2.innerProduct.inputChannels = 1024
    fc2.innerProduct.outputChannels = NUM_LABEL_INDEXES
    fc2.innerProduct.hasBias = True
    fc2.innerProduct.weights.floatValue.extend(tf_fc_weights_order_to_mlmodel(variables['W_fc2'].eval()).flatten())
    fc2.innerProduct.bias.floatValue.extend(variables['b_fc2'].eval().flatten())
    layers.extend([fc2])

    sm = mlmodel.NeuralNetworkLayer()
    sm.name = 'softmax'
    sm.input.extend(['fc2'])
    sm.output.extend(['labelValues'])
    sm.softmax.SetInParent()
    layers.extend([sm])

    f = open(file_name, 'wb')
    f.write(model.SerializeToString())
    f.close()

    print('Saved to file: %s' % file_name)
