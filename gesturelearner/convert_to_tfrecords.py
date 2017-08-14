from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import os
import sys

import click
import numpy as np
import tensorflow as tf

import protobuf.touches_pb2 as touches_pb2


@click.command()
@click.argument('in-file')
@click.option('--out-file')
def main(in_file, out_file):
    if out_file is None:
        file_name = os.path.splitext(in_file)[0]
        out_file = file_name + ".tfrecords"

    try:
        f = open(in_file, 'rb')
        training_set = touches_pb2.TrainingSet()
        training_set.ParseFromString(f.read())
        f.close()
    except FileNotFoundError:
        print('Could not find in-file "' + in_file + '"')
        return

    writer = tf.python_io.TFRecordWriter(out_file)

    for labelled_image in training_set.labelledImages:
        feature = {
            'height': tf.train.Feature(int64_list=tf.train.Int64List(value=[np.int64(labelled_image.image.height)])),
            'width': tf.train.Feature(int64_list=tf.train.Int64List(value=[np.int64(labelled_image.image.width)])),
            'label': tf.train.Feature(int64_list=tf.train.Int64List(value=[np.int64(compress_label(labelled_image.label))])),
            'image': tf.train.Feature(bytes_list=tf.train.BytesList(value=[labelled_image.image.values]))
        }

        example = tf.train.Example(features=tf.train.Features(feature=feature))

        writer.write(example.SerializeToString())

    writer.close()
    sys.stdout.flush()


def compress_label(label):
    label_values = touches_pb2.Label.values()

    try:
        return label_values.index(label)
    except ValueError:
        return 0


if __name__ == '__main__':
    main()
