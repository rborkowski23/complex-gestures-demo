import os
import sys


def add_mlmodel_to_path():
    sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), "../protobuf/mlmodel_specification/"))
