// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cassowary/cassowary.dart';

void main() {
  final solver = Solver();
  final left = Param(10);
  final right = Param(20);
  final widthAtLeast100 = right - left >= cm(100);
  final edgesPositive = (left >= cm(0))..priority = Priority.weak;
  solver
    ..addConstraints([widthAtLeast100, edgesPositive])
    ..flushUpdates();

  print('left: ${left.value}, right: ${right.value}');

  final mid = Variable(15);
  // It appears that == isn't defined
  solver
    ..addConstraint((left + right).equals(Term(mid, 1) * cm(2)))
    ..addEditVariable(mid, Priority.strong)
    ..flushUpdates();

  print('left: ${left.value}, mid: ${mid.value}, right: ${right.value}');
}
