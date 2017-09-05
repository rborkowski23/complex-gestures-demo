import os

import click
import tensorflow as tf

from gesturelearner import graph
from gesturelearner.constants import IMAGE_HEIGHT, IMAGE_WIDTH


@click.command()
@click.argument('model-in')
@click.option('--file-out')
def main(model_in, file_out):
    if file_out is None:
        [file_name, extension] = os.path.splitext(model_in)
        file_out = file_name + '.mlmodel'

    # Create the graph.
    predicted_labels, variables = graph.make_network(tf.placeholder(tf.float32, [None, IMAGE_HEIGHT, IMAGE_WIDTH, 1]))

    saver = tf.train.Saver()

    with tf.Session() as sess:
        try:
            saver.restore(sess, model_in)
            print('Restored model from file: %s' % model_in)
        except tf.errors.NotFoundError:
            print('Couldn\'t find model "%s".' % model_in)
            return

        graph.save_mlmodel(file_out, variables)

        return


if __name__ == '__main__':
    main()
