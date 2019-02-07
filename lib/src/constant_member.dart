// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'equation_member.dart';
import 'expression.dart';
import 'term.dart';

/// A member of a [Constraint] [Expression] that represent a constant at the
/// time the [Constraint] is added to the solver.
class ConstantMember extends EquationMember {
  /// Creates a [ConstantMember] object.
  ///
  /// The [cm] convenience method may be a more convenient way to create a
  /// [ConstantMember] object.
  ConstantMember(this.value);

  @override
  Expression asExpression() => Expression(<Term>[], value);

  @override
  final double value;

  @override
  bool get isConstant => true;
}

/// Creates a [ConstantMember].
///
/// This is a convenience method to make cassowary expressions less verbose.
ConstantMember cm(double value) => ConstantMember(value);
