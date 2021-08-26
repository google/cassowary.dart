// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'constant_member.dart';
import 'constraint.dart';
import 'equation_member.dart';
import 'param.dart';
import 'parser_exception.dart';
import 'term.dart';

class _Multiplication {
  const _Multiplication(this.multiplier, this.multiplicand);
  final Expression multiplier;
  final double multiplicand;
}

/// The representation of a linear [Expression] that can be used to create a
/// constraint.
class Expression extends EquationMember {
  /// Creates a new linear [Expression] using the given terms and constant.
  Expression(this.terms, this.constant);

  /// Creates a new linear [Expression] by copying the terms and constant of
  /// another expression.
  Expression.fromExpression(Expression expr)
      : terms = List<Term>.from(expr.terms),
        constant = expr.constant;

  /// The list of terms in this linear expression. Terms in a an [Expression]
  /// must have only one [Variable] (indeterminate) and a degree of 1.
  final List<Term> terms;

  /// The constant portion of this linear expression. This is just another
  /// [Term] with no [Variable].
  final double constant;

  @override
  Expression asExpression() => this;

  @override
  bool get isConstant => terms.isEmpty;

  @override
  double get value => terms.fold(constant, (value, term) => value + term.value);

  @override
  Constraint operator >=(EquationMember value) =>
      _createConstraint(value, Relation.greaterThanOrEqualTo);

  @override
  Constraint operator <=(EquationMember value) =>
      _createConstraint(value, Relation.lessThanOrEqualTo);

  @override
  Constraint equals(EquationMember value) =>
      _createConstraint(value, Relation.equalTo);

  Constraint _createConstraint(
      EquationMember /* rhs */ value, Relation relation) {
    if (value is ConstantMember) {
      return Constraint(
        Expression(List<Term>.from(terms), constant - value.value),
        relation,
      );
    }

    if (value is Param) {
      final newTerms = List<Term>.from(terms)..add(Term(value.variable, -1));
      return Constraint(Expression(newTerms, constant), relation);
    }

    if (value is Term) {
      final newTerms = List<Term>.from(terms)
        ..add(Term(value.variable, -value.coefficient));
      return Constraint(Expression(newTerms, constant), relation);
    }

    if (value is Expression) {
      final newTerms = value.terms.fold<List<Term>>(
        List<Term>.from(terms),
        (list, t) => list..add(Term(t.variable, -t.coefficient)),
      );
      return Constraint(
        Expression(newTerms, constant - value.constant),
        relation,
      );
    }

    throw Exception();
  }

  @override
  Expression operator +(EquationMember m) {
    if (m is ConstantMember) {
      return Expression(List<Term>.from(terms), constant + m.value);
    }

    if (m is Param) {
      return Expression(
        List<Term>.from(terms)..add(Term(m.variable, 1)),
        constant,
      );
    }

    if (m is Term) {
      return Expression(List<Term>.from(terms)..add(m), constant);
    }

    if (m is Expression) {
      return Expression(
        List<Term>.from(terms)..addAll(m.terms),
        constant + m.constant,
      );
    }
    throw Exception();
  }

  @override
  Expression operator -(EquationMember m) {
    if (m is ConstantMember) {
      return Expression(List<Term>.from(terms), constant - m.value);
    }

    if (m is Param) {
      return Expression(
        List<Term>.from(terms)..add(Term(m.variable, -1)),
        constant,
      );
    }

    if (m is Term) {
      return Expression(
        List<Term>.from(terms)..add(Term(m.variable, -m.coefficient)),
        constant,
      );
    }

    if (m is Expression) {
      final copiedTerms = List<Term>.from(terms);
      for (final t in m.terms) {
        copiedTerms.add(Term(t.variable, -t.coefficient));
      }
      return Expression(copiedTerms, constant - m.constant);
    }
    throw Exception();
  }

  @override
  Expression operator *(EquationMember m) {
    final args = _findMulitplierAndMultiplicand(m);

    if (args == null) {
      throw ParserException(
        'Could not find constant multiplicand or multiplier',
        <EquationMember>[this, m],
      );
    }

    return args.multiplier._applyMultiplicand(args.multiplicand);
  }

  @override
  Expression operator /(EquationMember m) {
    if (!m.isConstant) {
      throw ParserException('The divisor was not a constant expression',
          <EquationMember>[this, m]);
    }

    return _applyMultiplicand(1.0 / m.value);
  }

  _Multiplication? _findMulitplierAndMultiplicand(EquationMember m) {
    // At least one of the the two members must be constant for the resulting
    // expression to be linear

    if (!isConstant && !m.isConstant) {
      return null;
    }

    if (isConstant) {
      return _Multiplication(m.asExpression(), value);
    }

    if (m.isConstant) {
      return _Multiplication(asExpression(), m.value);
    }
    assert(false);
    return null;
  }

  Expression _applyMultiplicand(double m) {
    final newTerms = terms.fold<List<Term>>(
      [],
      (list, term) => list..add(Term(term.variable, term.coefficient * m)),
    );
    return Expression(newTerms, constant * m);
  }

  @override
  String toString() {
    final buffer = StringBuffer();

    for (final t in terms) {
      buffer.write('$t');
    }

    if (constant != 0.0) {
      buffer..write(constant.sign > 0.0 ? '+' : '-')..write(constant.abs());
    }

    return buffer.toString();
  }
}
