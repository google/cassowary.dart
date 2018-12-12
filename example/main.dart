// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cassowary/cassowary.dart';

void main() {
  var solver = Solver();
  var left = Param(10);
  var right = Param(20);
  var widthAtLeast100 = right - left >= cm(100.0);
  var edgesPositive = (left >= cm(0.0))..priority = Priority.weak;
  solver
    ..addConstraints([widthAtLeast100, edgesPositive])
    ..flushUpdates();

  print('left: ${left.value}, right: ${right.value}');

  var mid = Variable(15);
  // It appears that == isn't defined
  solver.addConstraint((left + right).equals(Term(mid, 1.0) * cm(2.0)));
  solver.addEditVariable(mid, Priority.strong);
  solver.flushUpdates();

  print('left: ${left.value}, mid: ${mid.value}, right: ${right.value}');
}
