#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Python version: 3.6

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import os
import copy
import numpy as np
from torchvision import datasets, transforms
import torch
import torch.nn.functional as F
from tensorboardX import SummaryWriter

from utils.sampling import mnist_iid, mnist_noniid, cifar_iid
from utils.options import args_parser
from models.Update import LocalUpdate
from models.Nets import MLP, CNNMnist, CNNCifar
from models.Fed import FedAvg


if __name__ == '__main__':
    net_glob = torch.load('trained_model.pt')
    net_glob.eval()

    dataset = datasets.MNIST('./data/mnist/', train=True, download=True,
                transform=transforms.Compose([
                transforms.ToTensor(),
                transforms.Normalize((0.1307,), (0.3081,))
            ]))

    print(dataset[0])