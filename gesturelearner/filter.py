from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import os
import random
import sys

import click

import protobuf.touches_pb2 as touches_pb2


@click.command()
@click.argument('in-file')
@click.option('--out-file')
@click.option('--merge-file')
@click.option('--shuffle/--no-shuffle', default=True)
@click.option('--test-fraction', default=0, type=float)
@click.option('--exclude-with-label', type=int, multiple=True)
@click.option('--include-with-label', type=int, multiple=True)
def main(in_file, out_file, merge_file, shuffle, test_fraction, exclude_with_label, include_with_label):
    if out_file is None:
        [file_name, extension] = os.path.splitext(in_file)
        out_file = file_name + "_filtered" + extension

    if len(exclude_with_label) > 0 and len(include_with_label) > 0:
        print('Cannot specify both --exclude-with-label and --include-with-label.', file=sys.stderr)
        return

    try:
        f = open(in_file, 'rb')
        training_set = touches_pb2.TrainingSet()
        training_set.ParseFromString(f.read())
        f.close()
    except FileNotFoundError:
        print('Could not find in-file "' + in_file + '"', file=sys.stderr)
        return

    images = [image for image in training_set.labelledImages]
    print('Loaded %s images from in-file.' % len(images))

    if merge_file is not None:
        try:
            f = open(merge_file, 'rb')
            merge_set = touches_pb2.TrainingSet()
            merge_set.ParseFromString(f.read())
            f.close()

            images_before_merge = len(images)
            images.extend([image for image in merge_set.labelledImages])
            print('Merged %s images from "%s" with %s from "%s" for a total of %s.'
                  % (images_before_merge, in_file, len(images) - images_before_merge, merge_file, len(images)))

        except FileNotFoundError:
            print('Could not find merge-file "' + merge_file + '"', file=sys.stderr)
            return

    filtered_images = []

    for image in images:
        if len(exclude_with_label) > 0 and image.label in exclude_with_label:
            continue

        if len(include_with_label) > 0 and (not image.label in include_with_label):
            continue

        filtered_images.append(image)

    print('Images after exclusion/inclusion: %s' % len(filtered_images))

    if shuffle:
        print('Shuffling images.')
        random.shuffle(filtered_images)

    test_fraction = max(0, min(test_fraction, 1))

    example_count = len(filtered_images)
    test_example_count = int(round(example_count * test_fraction))

    if test_example_count > 0:
        [file_name, extension] = os.path.splitext(out_file)
        test_file = file_name + "_test" + extension
        save_examples(filtered_images[0:test_example_count], test_file)
        print('Saved %s testing images to "%s".' % (test_example_count, test_file))

    save_examples(filtered_images[test_example_count:], out_file)
    print('Saved %s training images to "%s".' % (example_count - test_example_count, out_file))


def save_examples(labelled_images, file_name):
    f = open(file_name, 'wb')
    training_set = touches_pb2.TrainingSet()
    training_set.labelledImages.extend(labelled_images)
    f.write(training_set.SerializeToString())
    f.close()


if __name__ == '__main__':
    main()
