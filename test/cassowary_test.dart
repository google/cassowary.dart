// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import 'package:cassowary/cassowary.dart';
import 'package:matcher/matcher.dart';

void main() {
  test('variable', () {
    final v = Param(22);
    expect(v.value, 22);
  });

  test('variable1', () {
    final v = Param(22);
    expect((v + cm(22)).value, 44.0);
    expect((v - cm(20)).value, 2.0);
  });

  test('term', () {
    final t = Term(Variable(22), 2);
    expect(t.value, 44);
  });

  test('expression', () {
    final terms = <Term>[
      Term(Variable(22), 2),
      Term(Variable(1), 1),
    ];
    final e = Expression(terms, 40);
    expect(e.value, 85.0);
  });

  test('expression1', () {
    final v1 = Param(10);
    final v2 = Param(10);
    final v3 = Param(22);

    expect(v1 is Param, true);
    expect(v1 + cm(20) is Expression, true);
    expect(v1 + v2 is Expression, true);

    expect((v1 + v2).value, 20.0);
    expect((v1 - v2).value, 0.0);

    expect((v1 + v2 + v3) is Expression, true);
    expect((v1 + v2 + v3).value, 42.0);
  });

  test('expression2', () {
    final e = Param(10) + cm(5);
    expect(e.value, 15.0);
    expect(e is Expression, true);

    // Constant
    expect((e + cm(2)) is Expression, true);
    expect((e + cm(2)).value, 17.0);
    expect((e - cm(2)) is Expression, true);
    expect((e - cm(2)).value, 13.0);

    expect(e.value, 15.0);

    // Param
    final v = Param(2);
    expect((e + v) is Expression, true);
    expect((e + v).value, 17.0);
    expect((e - v) is Expression, true);
    expect((e - v).value, 13.0);

    expect(e.value, 15.0);

    // Term
    final t = Term(v.variable, 2);
    expect((e + t) is Expression, true);
    expect((e + t).value, 19.0);
    expect((e - t) is Expression, true);
    expect((e - t).value, 11.0);

    expect(e.value, 15.0);

    // Expression
    final e2 = Param(7) + Param(3);
    expect((e + e2) is Expression, true);
    expect((e + e2).value, 25.0);
    expect((e - e2) is Expression, true);
    expect((e - e2).value, 5.0);

    expect(e.value, 15.0);
  });

  test('term2', () {
    final t = Term(Variable(12), 1);

    // Constant
    final c = cm(2);
    expect((t + c) is Expression, true);
    expect((t + c).value, 14.0);
    expect((t - c) is Expression, true);
    expect((t - c).value, 10.0);

    // Variable
    final v = Param(2);
    expect((t + v) is Expression, true);
    expect((t + v).value, 14.0);
    expect((t - v) is Expression, true);
    expect((t - v).value, 10.0);

    // Term
    final t2 = Term(Variable(1), 2);
    expect((t + t2) is Expression, true);
    expect((t + t2).value, 14.0);
    expect((t - t2) is Expression, true);
    expect((t - t2).value, 10.0);

    // Expression
    final exp = Param(1) + cm(1);
    expect((t + exp) is Expression, true);
    expect((t + exp).value, 14.0);
    expect((t - exp) is Expression, true);
    expect((t - exp).value, 10.0);
  });

  test('variable3', () {
    final v = Param(3);

    // Constant
    final c = cm(2);
    expect((v + c) is Expression, true);
    expect((v + c).value, 5.0);
    expect((v - c) is Expression, true);
    expect((v - c).value, 1.0);

    // Variable
    final v2 = Param(2);
    expect((v + v2) is Expression, true);
    expect((v + v2).value, 5.0);
    expect((v - v2) is Expression, true);
    expect((v - v2).value, 1.0);

    // Term
    final t2 = Term(Variable(1), 2);
    expect((v + t2) is Expression, true);
    expect((v + t2).value, 5.0);
    expect((v - t2) is Expression, true);
    expect((v - t2).value, 1.0);

    // Expression
    final exp = Param(1) + cm(1);
    expect(exp.terms.length, 1);

    expect((v + exp) is Expression, true);
    expect((v + exp).value, 5.0);
    expect((v - exp) is Expression, true);
    expect((v - exp).value, 1.0);
  });

  test('constantmember', () {
    final c = cm(3);

    // Constant
    final c2 = cm(2);
    expect((c + c2) is Expression, true);
    expect((c + c2).value, 5.0);
    expect((c - c2) is Expression, true);
    expect((c - c2).value, 1.0);

    // Variable
    final v2 = Param(2);
    expect((c + v2) is Expression, true);
    expect((c + v2).value, 5.0);
    expect((c - v2) is Expression, true);
    expect((c - v2).value, 1.0);

    // Term
    final t2 = Term(Variable(1), 2);
    expect((c + t2) is Expression, true);
    expect((c + t2).value, 5.0);
    expect((c - t2) is Expression, true);
    expect((c - t2).value, 1.0);

    // Expression
    final exp = Param(1) + cm(1);

    expect((c + exp) is Expression, true);
    expect((c + exp).value, 5.0);
    expect((c - exp) is Expression, true);
    expect((c - exp).value, 1.0);
  });

  test('constraint2', () {
    final left = Param(10);
    final right = Param(100);

    final c = right - left >= cm(25);
    expect(c is Constraint, true);
  });

  test('simple_multiplication', () {
    // Constant
    final c = cm(20);
    expect((c * cm(2)).value, 40.0);

    // Variable
    final v = Param(20);
    expect((v * cm(2)).value, 40.0);

    // Term
    final t = Term(v.variable, 1);
    expect((t * cm(2)).value, 40.0);

    // Expression
    final e = Expression(<Term>[t], 0);
    expect((e * cm(2)).value, 40.0);
  });

  test('simple_division', () {
    // Constant
    final c = cm(20);
    expect((c / cm(2)).value, 10.0);

    // Variable
    final v = Param(20);
    expect((v / cm(2)).value, 10.0);

    // Term
    final t = Term(v.variable, 1);
    expect((t / cm(2)).value, 10.0);

    // Expression
    final e = Expression(<Term>[t], 0);
    expect((e / cm(2)).value, 10.0);
  });

  test('full_constraints_setup', () {
    final left = Param(2);
    final right = Param(10);

    final c1 = right - left >= cm(20);
    expect(c1 is Constraint, true);
    expect(c1.expression.constant, -20.0);
    expect(c1.relation, Relation.greaterThanOrEqualTo);

    final c2 = (right - left).equals(cm(30));
    expect(c2 is Constraint, true);
    expect(c2.expression.constant, -30.0);
    expect(c2.relation, Relation.equalTo);

    final c3 = right - left <= cm(30);
    expect(c3 is Constraint, true);
    expect(c3.expression.constant, -30.0);
    expect(c3.relation, Relation.lessThanOrEqualTo);
  });

  test('constraint_strength_update', () {
    final left = Param(2);
    final right = Param(10);

    final c = (right - left >= cm(200)) | 750.0;
    expect(c is Constraint, true);
    expect(c.expression.terms.length, 2);
    expect(c.expression.constant, -200.0);
    expect(c.priority, 750.0);
  });

  test('solver', () {
    final s = Solver();

    final left = Param(2);
    final right = Param(100);

    final c1 = right - left >= cm(200);

    expect((right >= left) is Constraint, true);

    expect(s.addConstraint(c1), Result.success);
  });

  test('constraint_complex', () {
    final e = Param(200) - Param(100);

    // Constant
    final c1 = e >= cm(50);
    expect(c1 is Constraint, true);
    expect(c1.expression.terms.length, 2);
    expect(c1.expression.constant, -50.0);

    // Variable
    final c2 = e >= Param(2);
    expect(c2 is Constraint, true);
    expect(c2.expression.terms.length, 3);
    expect(c2.expression.constant, 0.0);

    // Term
    final c3 = e >= Term(Variable(2), 1);
    expect(c3 is Constraint, true);
    expect(c3.expression.terms.length, 3);
    expect(c3.expression.constant, 0.0);

    // Expression
    final c4 = e >= Expression(<Term>[Term(Variable(2), 1)], 20);
    expect(c4 is Constraint, true);
    expect(c4.expression.terms.length, 3);
    expect(c4.expression.constant, -20.0);
  });

  test('constraint_complex_non_exprs', () {
    // Constant
    final c1 = cm(100) >= cm(50);
    expect(c1 is Constraint, true);
    expect(c1.expression.terms.length, 0);
    expect(c1.expression.constant, 50.0);

    // Variable
    final c2 = Param(100) >= Param(2);
    expect(c2 is Constraint, true);
    expect(c2.expression.terms.length, 2);
    expect(c2.expression.constant, 0.0);

    // Term
    final t = Term(Variable(100), 1);
    final c3 = t >= Term(Variable(2), 1);
    expect(c3 is Constraint, true);
    expect(c3.expression.terms.length, 2);
    expect(c3.expression.constant, 0.0);

    // Expression
    final e = Expression(<Term>[t], 0);
    final c4 = e >= Expression(<Term>[Term(Variable(2), 1)], 20);
    expect(c4 is Constraint, true);
    expect(c4.expression.terms.length, 2);
    expect(c4.expression.constant, -20.0);
  });

  test('constraint_update_in_solver', () {
    final s = Solver();

    final left = Param(2);
    final right = Param(100);

    final c1 = right - left >= cm(200);
    final c2 = right >= right;

    expect(s.addConstraint(c1), Result.success);
    expect(s.addConstraint(c1), Result.duplicateConstraint);
    expect(s.removeConstraint(c2), Result.unknownConstraint);
    expect(s.removeConstraint(c1), Result.success);
    expect(s.removeConstraint(c1), Result.unknownConstraint);
  });

  test('test_multiplication_division_override', () {
    final c = cm(10);
    final v = Param(c.value);
    final t = Term(v.variable, 1);
    final e = Expression(<Term>[t], 0);

    // Constant
    expect((c * cm(10)).value, 100);

    // Variable
    expect((v * cm(10)).value, 100);

    // Term
    expect((t * cm(10)).value, 100);

    // Expression
    expect((e * cm(10)).value, 100);

    // Constant
    expect((c / cm(10)).value, 1);

    // Variable
    expect((v / cm(10)).value, 1);

    // Term
    expect((t / cm(10)).value, 1);

    // Expression
    expect((e / cm(10)).value, 1);
  });

  test('test_multiplication_division_exceptions', () {
    final c = cm(10);
    final v = Param(c.value);
    final t = Term(v.variable, 1);
    final e = Expression(<Term>[t], 0);

    expect((c * c).value, 100);
    expect(() => v * v, throwsA(const TypeMatcher<ParserException>()));
    expect(() => v / v, throwsA(const TypeMatcher<ParserException>()));
    expect(() => v * t, throwsA(const TypeMatcher<ParserException>()));
    expect(() => v / t, throwsA(const TypeMatcher<ParserException>()));
    expect(() => v * e, throwsA(const TypeMatcher<ParserException>()));
    expect(() => v / e, throwsA(const TypeMatcher<ParserException>()));
    expect(() => v * c, returnsNormally);
    expect(() => v / c, returnsNormally);
  });

  test('edit_updates', () {
    final s = Solver();

    final left = Param(0);
    final right = Param(100);
    final mid = Param(0);

    final c = left + right >= cm(2) * mid;
    expect(s.addConstraint(c), Result.success);

    expect(s.addEditVariable(mid.variable, 999), Result.success);
    expect(s.addEditVariable(mid.variable, 999), Result.duplicateEditVariable);
    expect(s.removeEditVariable(mid.variable), Result.success);
    expect(s.removeEditVariable(mid.variable), Result.unknownEditVariable);
  });

  test('bug1', () {
    final left = Param(0);
    final right = Param(100);
    final mid = Param(0);

    expect(((left + right) >= (cm(2) * mid)) is Constraint, true);
  });

  test('single_item', () {
    final left = Param(-20);
    Solver()
      ..addConstraint(left >= cm(0))
      ..flushUpdates();
    expect(left.value, 0.0);
  });

  test('midpoints', () {
    final left = Param(0)..name = 'left';
    final right = Param(0)..name = 'right';
    final mid = Param(0)..name = 'mid';

    final s = Solver();

    expect(s.addConstraint((right + left).equals(mid * cm(2))), Result.success);
    expect(s.addConstraint(right - left >= cm(100)), Result.success);
    expect(s.addConstraint(left >= cm(0)), Result.success);

    s.flushUpdates();

    expect(left.value, 0.0);
    expect(mid.value, 50.0);
    expect(right.value, 100.0);
  });

  test('addition_of_multiple', () {
    final left = Param(0);
    final right = Param(0);
    final mid = Param(0);

    final s = Solver();

    final c = (left >= cm(0));

    expect(
        s.addConstraints(<Constraint>[
          (left + right).equals(cm(2) * mid),
          (right - left >= cm(100)),
          c
        ]),
        Result.success);

    expect(s.addConstraints(<Constraint>[(right >= cm(-20)), c]),
        Result.duplicateConstraint);
  });

  test('edit_constraints', () {
    final left = Param(0)..name = 'left';
    final right = Param(0)..name = 'right';
    final mid = Param(0)..name = 'mid';

    final s = Solver();

    expect(s.addConstraint((right + left).equals(mid * cm(2))), Result.success);
    expect(s.addConstraint(right - left >= cm(100)), Result.success);
    expect(s.addConstraint(left >= cm(0)), Result.success);

    expect(s.addEditVariable(mid.variable, Priority.strong), Result.success);
    expect(s.suggestValueForVariable(mid.variable, 300), Result.success);

    s.flushUpdates();

    expect(left.value, 0.0);
    expect(mid.value, 300.0);
    expect(right.value, 600.0);
  });

  test('test_description', () {
    final left = Param(0);
    final right = Param(100);
    final c1 = right >= left;
    final c2 = right <= left;
    final c3 = right.equals(left);

    final s = Solver();
    expect(s.addConstraint(c1), Result.success);
    expect(s.addConstraint(c2), Result.success);
    expect(s.addConstraint(c3), Result.success);

    expect(s.toString(), true);
  });

  test('solution_with_optimize', () {
    final p1 = Param();
    final p2 = Param();
    final p3 = Param();

    final container = Param();

    Solver()
      ..addEditVariable(container.variable, Priority.strong)
      ..suggestValueForVariable(container.variable, 100)
      ..addConstraint((p1 >= cm(30)) | Priority.strong)
      ..addConstraint(p1.equals(p3) | Priority.medium)
      ..addConstraint(p2.equals(cm(2) * p1))
      ..addConstraint(container.equals(p1 + p2 + p3))
      ..flushUpdates();

    expect(container.value, 100.0);

    expect(p1.value, 30.0);
    expect(p2.value, 60.0);
    expect(p3.value, 10.0);
  });

  test('test_updates_collection', () {
    final left = Param.withContext('left');
    final mid = Param.withContext('mid');
    final right = Param.withContext('right');

    final s = Solver();

    expect(s.addEditVariable(mid.variable, Priority.strong), Result.success);

    expect(s.addConstraint((mid * cm(2)).equals(left + right)), Result.success);
    expect(s.addConstraint(left >= cm(0)), Result.success);

    expect(s.suggestValueForVariable(mid.variable, 50), Result.success);

    final updates = s.flushUpdates();

    expect(updates.length, 2);

    expect(left.value, 0.0);
    expect(mid.value, 50.0);
    expect(right.value, 100.0);
  });

  test('test_updates_collection_is_set', () {
    final left = Param.withContext('a');
    final mid = Param.withContext('a');
    final right = Param.withContext('a');

    final s = Solver();

    expect(s.addEditVariable(mid.variable, Priority.strong), Result.success);

    expect(s.addConstraint((mid * cm(2)).equals(left + right)), Result.success);
    expect(s.addConstraint(left >= cm(10)), Result.success);

    expect(s.suggestValueForVariable(mid.variable, 50), Result.success);

    final updates = s.flushUpdates();

    expect(updates.length, 1);

    expect(left.value, 10.0);
    expect(mid.value, 50.0);
    expect(right.value, 90.0);
  });

  test('param_context_non_final', () {
    final p = Param.withContext('a')..context = 'b';
    expect(p.context, 'b');
  });

  test('check_type_of_eq_result', () {
    final left = Param();
    final right = Param();

    expect(left.equals(right).runtimeType, Constraint);
  });

  test('bulk_add_edit_variables', () {
    final s = Solver();

    final left = Param(0);
    final right = Param(100);
    final mid = Param(0);

    expect(
        s.addEditVariables(
            <Variable>[left.variable, right.variable, mid.variable], 999),
        Result.success);
  });

  test('bulk_remove_constraints_and_variables', () {
    final s = Solver();

    final left = Param(0);
    final right = Param(100);
    final mid = Param(0);

    expect(
        s.addEditVariables(
            <Variable>[left.variable, right.variable, mid.variable], 999),
        Result.success);

    final c1 = left <= mid;
    final c2 = mid <= right;

    expect(s.addConstraints(<Constraint>[c1, c2]), Result.success);

    expect(s.removeConstraints(<Constraint>[c1, c2]), Result.success);

    expect(
        s.removeEditVariables(
            <Variable>[left.variable, right.variable, mid.variable]),
        Result.success);
  });
}
