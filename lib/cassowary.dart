// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// An implementation of the Cassowary constraint solving algorithm in Dart.
///
/// To use, import `package:cassowary/cassowary.dart`.
///
/// See also:
///
/// * <https://en.wikipedia.org/wiki/Cassowary_(software)>
/// * <https://constraints.cs.washington.edu/solvers/cassowary-tochi.pdf>
library cassowary;

export 'src/constant_member.dart';
export 'src/constraint.dart';
export 'src/equation_member.dart';
export 'src/expression.dart';
export 'src/param.dart';
export 'src/parser_exception.dart';
export 'src/priority.dart';
export 'src/result.dart';
export 'src/solver.dart';
export 'src/term.dart';
