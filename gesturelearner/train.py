import click
import numpy as np
import tensorflow as tf

from gesturelearner import graph
from gesturelearner.constants import IMAGE_HEIGHT, IMAGE_WIDTH, NUM_LABEL_INDEXES


@click.command()
@click.argument('training-file')
@click.option('--test-file')
@click.option('--model-in')
@click.option('--model-out')
def main(training_file, test_file, model_in, model_out):
    if model_in is None:
        model_in = "model.ckpt"

    if model_out is None:
        model_out = model_in

    train_images, train_labels = read_train_file(training_file)

    is_testing = False
    if test_file is not None:
        is_testing = True
        test_images, test_labels = read_test_file(test_file)

    images_input = tf.placeholder(tf.float32, [None, IMAGE_HEIGHT, IMAGE_WIDTH, 1])
    labels_input = tf.placeholder(tf.float32, [None, NUM_LABEL_INDEXES])

    predicted_labels, variables = graph.make_network(images_input)

    cross_entropy = tf.reduce_mean(
        tf.nn.softmax_cross_entropy_with_logits(labels=labels_input, logits=predicted_labels))
    train_step = tf.train.AdamOptimizer(1e-4).minimize(cross_entropy)
    correct_prediction = tf.equal(tf.argmax(predicted_labels, 1), tf.argmax(labels_input, 1))
    accuracy = tf.reduce_mean(tf.cast(correct_prediction, tf.float32))

    # misclassified = tf.where(tf.logical_not(correct_prediction))

    init_op = tf.group(tf.global_variables_initializer(),
                       tf.local_variables_initializer())

    saver = tf.train.Saver()

    with tf.Session() as sess:
        sess.run(init_op)

        if tf.train.checkpoint_exists(model_in):
            saver.restore(sess, model_in)
            print("Restored model from file: %s" % model_in)
        else:
            print("Couldn't find model \"%s\". Training a new model from scratch." % model_in)

        coord = tf.train.Coordinator()
        threads = tf.train.start_queue_runners(coord=coord)

        try:
            # wrong_indexes, labels = sess.run([misclassified, tf.argmax(predicted_labels, 1)], {variables['keep_prob']: 1.0, images_input: test_images, labels_input: test_labels})
            #
            # for value in wrong_indexes:
            #     print('Wrong prediction at %s. Predicted label: %s' % (value[0], labels[value[0]]))

            for i in range(20000):
                next_images, next_labels = sess.run([train_images, train_labels])

                if i % 10 == 0:
                    train_accuracy = accuracy.eval({variables['keep_prob']: 1.0, images_input: next_images, labels_input: next_labels})
                    print('step %d, training accuracy %g' % (i, train_accuracy))

                if i % 50 == 0 and is_testing:
                    test_accuracy = accuracy.eval({variables['keep_prob']: 1.0, images_input: test_images, labels_input: test_labels})
                    print('step %d, testing accuracy %g' % (i, test_accuracy))

                if i % 100 == 0:
                    save_path = saver.save(sess, model_out)
                    print("Saved model in file: %s" % save_path)

                train_step.run(feed_dict={variables['keep_prob']: 0.5, images_input: next_images, labels_input: next_labels})
        finally:
            coord.request_stop()
            coord.join(threads)


def read_train_file(file_name):
    images, labels = read(tf.train.string_input_producer([file_name]))

    images, labels = tf.train.shuffle_batch(
        [images, labels],
         batch_size=50,
         capacity=200,
         num_threads=2,
         min_after_dequeue=0
    )

    return images, labels


def read_test_file(file_name):
    record_iterator = tf.python_io.tf_record_iterator(path=file_name)
    images = []
    labels = []

    for string_record in record_iterator:
        example = tf.train.Example()
        example.ParseFromString(string_record)

        height = int(example.features.feature['height'].int64_list.value[0])
        width = int(example.features.feature['width'].int64_list.value[0])
        label_index = np.int64(example.features.feature['label'].int64_list.value[0])
        image = example.features.feature['image'].bytes_list.value[0]

        label = np.zeros(NUM_LABEL_INDEXES, dtype=np.float32)
        label[label_index] = 1.0

        image = np.fromstring(image, dtype=np.uint8)
        image = image * (1. / 255) - 0.5
        image = np.reshape(image, (height, width, 1))

        images.append(image)
        labels.append(label)

    return images, labels


def read(file_name_queue):
    reader = tf.TFRecordReader()

    _, serialized_example = reader.read(file_name_queue)

    features = tf.parse_single_example(
      serialized_example,
      features={
        'height': tf.FixedLenFeature([], tf.int64),
        'width': tf.FixedLenFeature([], tf.int64),
        'label': tf.FixedLenFeature([], tf.int64),
        'image': tf.FixedLenFeature([], tf.string)
    })

    height = tf.cast(features['height'], tf.int32)
    width = tf.cast(features['width'], tf.int32)
    label = tf.cast(features['label'], tf.int64)
    image = tf.decode_raw(features['image'], tf.uint8)

    label_index = tf.reshape(label, [1, 1])

    sparse_tensor = tf.SparseTensor(label_index, [1.0], [NUM_LABEL_INDEXES])
    label = tf.sparse_tensor_to_dense(sparse_tensor)

    image = tf.cast(image, tf.float32)
    image = image * (1. / 255) - 0.5
    image = tf.reshape(image, [height, width, 1])

    resized_image = tf.image.resize_image_with_crop_or_pad(
        image=image,
        target_height=IMAGE_HEIGHT,
        target_width=IMAGE_WIDTH
    )

    return resized_image, label


if __name__ == '__main__':
    main()