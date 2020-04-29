// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'constraint.dart';
import 'expression.dart';
import 'param.dart';
import 'priority.dart';
import 'result.dart';
import 'term.dart';

enum _SymbolType { invalid, external, slack, error, dummy }

class _Symbol {
  _Symbol(this.type);

  final _SymbolType type;
}

class _Tag {
  _Tag(this.marker, this.other);
  _Tag.fromTag(_Tag tag)
      : marker = tag.marker,
        other = tag.other;
  _Symbol marker;
  _Symbol other;
}

class _EditInfo {
  _Tag tag;
  Constraint constraint;
  double constant;
}

bool _isValidNonRequiredPriority(double priority) =>
    (priority >= 0.0 && priority < Priority.required);

typedef _SolverBulkUpdate = Result Function(Object);

bool _nearZero(double value) {
  const epsilon = 1.0e-8;
  return value < 0.0 ? -value < epsilon : value < epsilon;
}

class _Row {
  _Row(this.constant) : cells = {};

  _Row.fromRow(_Row row)
      : cells = Map<_Symbol, double>.from(row.cells),
        constant = row.constant;

  final Map<_Symbol, double> cells;

  double constant = 0;

  double add(double value) => constant += value;

  void insertSymbol(_Symbol symbol, [double coefficient = 1.0]) {
    final val = cells[symbol] ?? 0.0;

    if (_nearZero(val + coefficient)) {
      cells.remove(symbol);
    } else {
      cells[symbol] = val + coefficient;
    }
  }

  void insertRow(_Row other, [double coefficient = 1.0]) {
    constant += other.constant * coefficient;
    other.cells.forEach((s, v) => insertSymbol(s, v * coefficient));
  }

  void removeSymbol(_Symbol symbol) {
    cells.remove(symbol);
  }

  void reverseSign() {
    constant = -constant;
    cells.forEach((s, v) => cells[s] = -v);
  }

  void solveForSymbol(_Symbol symbol) {
    assert(cells.containsKey(symbol));
    final coefficient = -1.0 / cells[symbol];
    cells.remove(symbol);
    constant *= coefficient;
    cells.forEach((s, v) => cells[s] = v * coefficient);
  }

  void solveForSymbols(_Symbol lhs, _Symbol rhs) {
    insertSymbol(lhs, -1);
    solveForSymbol(rhs);
  }

  double coefficientForSymbol(_Symbol symbol) => cells[symbol] ?? 0.0;

  void substitute(_Symbol symbol, _Row row) {
    final coefficient = cells[symbol];

    if (coefficient == null) {
      return;
    }

    cells.remove(symbol);
    insertRow(row, coefficient);
  }

  @override
  String toString() {
    final buffer = StringBuffer()..write(constant);

    cells.forEach((symbol, value) {
      buffer.write('${value.toString()} * ${symbol.toString()}');
    });

    return buffer.toString();
  }
}

/// Solves cassowary constraints.
///
/// Typically clients will create a solver, [addConstraints], and then call
/// [flushUpdates] to actually solve the constraints.
class Solver {
  final Map<Constraint, _Tag> _constraints = {};
  final Map<_Symbol, _Row> _rows = {};
  final Map<Variable, _Symbol> _vars = {};
  final Map<Variable, _EditInfo> _edits = {};
  final List<_Symbol> _infeasibleRows = [];
  final _Row _objective = _Row(0);

  _Row _artificial = _Row(0);

  /// Attempts to add the constraints in the list to the solver. If it cannot
  /// add any for some reason, a cleanup is attempted so that either all
  /// constraints will be added or none.
  ///
  /// Check the [Result] returned to make sure the operation succeeded. Any
  /// errors will be reported via the `message` property on the [Result].
  ///
  /// Possible [Result]s:
  ///
  /// * [Result.success]: All constraints successfully added.
  /// * [Result.duplicateConstraint]: One of the constraints in the list was
  ///   already in the solver or the same constraint was specified multiple
  ///   times in the argument list. Remove the duplicates and try again.
  /// * [Result.unsatisfiableConstraint]: One or more constraints were at
  ///   [Priority.required] but could not added because of conflicts with other
  ///   constraints at the same priority. Lower the priority of these
  ///   constraints and try again.
  Result addConstraints(List<Constraint> constraints) {
    Result _applier(c) => addConstraint(c);
    Result _undoer(c) => removeConstraint(c);

    return _bulkEdit(constraints, _applier, _undoer);
  }

  /// Attempts to add an individual [Constraint] to the solver.
  ///
  /// Check the [Result] returned to make sure the operation succeeded. Any
  /// errors will be reported via the `message` property on the [Result].
  ///
  /// Possible [Result]s:
  ///
  /// * [Result.success]: The constraint was successfully added.
  /// * [Result.duplicateConstraint]: The constraint was already present in the
  ///   solver.
  /// * [Result.unsatisfiableConstraint]: The constraint was at
  ///   [Priority.required] but could not be added because of a conflict with
  ///   another constraint at that priority already in the solver. Try lowering
  ///   the priority of the constraint and try again.
  Result addConstraint(Constraint constraint) {
    if (_constraints.containsKey(constraint)) {
      return Result.duplicateConstraint;
    }

    final tag = _Tag(
      _Symbol(_SymbolType.invalid),
      _Symbol(_SymbolType.invalid),
    );

    final row = _createRow(constraint, tag);

    var subject = _chooseSubjectForRow(row, tag);

    if (subject.type == _SymbolType.invalid && _allDummiesInRow(row)) {
      if (!_nearZero(row.constant)) {
        return Result.unsatisfiableConstraint;
      } else {
        subject = tag.marker;
      }
    }

    if (subject.type == _SymbolType.invalid) {
      if (!_addWithArtificialVariableOnRow(row)) {
        return Result.unsatisfiableConstraint;
      }
    } else {
      row.solveForSymbol(subject);
      _substitute(subject, row);
      _rows[subject] = row;
    }

    _constraints[constraint] = tag;

    return _optimizeObjectiveRow(_objective);
  }

  /// Attempts to remove a list of constraints from the solver. Either all
  /// constraints are removed or none. If more fine-grained control over the
  /// removal is required (for example, not failing on removal of constraints
  /// not already present in the solver), try removing the each [Constraint]
  /// individually and check the result on each attempt.
  ///
  /// Check the [Result] returned to make sure the operation succeeded. Any
  /// errors will be reported via the `message` property on the [Result].
  ///
  /// Possible [Result]s:
  ///
  /// * [Result.success]: The constraints were successfully removed from the
  ///   solver.
  /// * [Result.unknownConstraint]: One or more constraints in the list were
  ///   not in the solver. So there was nothing to remove.
  Result removeConstraints(List<Constraint> constraints) {
    Result _applier(c) => removeConstraint(c);
    Result _undoer(c) => addConstraint(c);

    return _bulkEdit(constraints, _applier, _undoer);
  }

  /// Attempt to remove an individual [Constraint] from the solver.
  ///
  /// Check the [Result] returned to make sure the operation succeeded. Any
  /// errors will be reported via the `message` property on the [Result].
  ///
  /// Possible [Result]s:
  ///
  /// * [Result.success]: The [Constraint] was successfully removed from the
  ///   solver.
  /// * [Result.unknownConstraint]: The [Constraint] was not in the solver so
  ///   there was nothing to remove.
  Result removeConstraint(Constraint constraint) {
    var tag = _constraints[constraint];
    if (tag == null) {
      return Result.unknownConstraint;
    }

    tag = _Tag.fromTag(tag);
    _constraints.remove(constraint);

    _removeConstraintEffects(constraint, tag);

    var row = _rows[tag.marker];
    if (row != null) {
      _rows.remove(tag.marker);
    } else {
      final leaving = _leavingSymbolForMarkerSymbol(tag.marker);
      assert(leaving != null);

      row = _rows.remove(leaving);
      assert(row != null);
      row.solveForSymbols(leaving, tag.marker);
      _substitute(tag.marker, row);
    }

    return _optimizeObjectiveRow(_objective);
  }

  /// Returns whether the given [Constraint] is present in the solver.
  bool hasConstraint(Constraint constraint) =>
      _constraints.containsKey(constraint);

  /// Adds a list of edit [Variable]s to the [Solver] at a given priority.
  /// Either all edit [Variable] are added or none. No edit variables may be
  /// added at `Priority.required`.
  ///
  /// Check the [Result] returned to make sure the operation succeeded. Any
  /// errors will be reported via the `message` property on the [Result].
  ///
  /// Possible [Result]s:
  ///
  /// * [Result.success]: The edit variables were successfully added to [Solver]
  ///   at the specified priority.
  /// * [Result.duplicateEditVariable]: One of more edit variables were already
  ///   present in the [Solver] or the same edit variables were specified
  ///   multiple times in the list. Remove the duplicates and try again.
  /// * [Result.badRequiredStrength]: The edit variables were added at
  ///   [Priority.required]. Edit variables are used to
  ///   suggest values to the solver. Since suggestions can't be mandatory,
  ///   priorities cannot be [Priority.required]. If variable values need to be
  ///   fixed at [Priority.required], add that preference as a constraint. This
  ///   allows the solver to check for satisfiability of the constraint (w.r.t
  ///   other constraints at [Priority.required]) and check for duplicates.
  Result addEditVariables(List<Variable> variables, double priority) {
    Result _applier(v) => addEditVariable(v, priority);
    Result _undoer(v) => removeEditVariable(v);

    return _bulkEdit(variables, _applier, _undoer);
  }

  /// Attempt to add a single edit [Variable] to the [Solver] at the given
  /// priority. No edit variables may be added to the [Solver] at
  /// `Priority.required`.
  ///
  /// Check the [Result] returned to make sure the operation succeeded. Any
  /// errors will be reported via the `message` property on the [Result].
  ///
  /// Possible [Result]s:
  ///
  /// * [Result.success]: The edit variable was successfully added to [Solver]
  ///   at the specified priority.
  /// * [Result.duplicateEditVariable]: The edit variable was already present
  ///   in the [Solver].
  /// * [Result.badRequiredStrength]: The edit variable was added at
  ///   [Priority.required]. Edit variables are used to
  ///   suggest values to the solver. Since suggestions can't be mandatory,
  ///   priorities cannot be [Priority.required]. If variable values need to be
  ///   fixed at [Priority.required], add that preference as a constraint. This
  ///   allows the solver to check for satisfiability of the constraint (w.r.t
  ///   other constraints at [Priority.required]) and check for duplicates.
  Result addEditVariable(Variable variable, double priority) {
    if (_edits.containsKey(variable)) {
      return Result.duplicateEditVariable;
    }

    if (!_isValidNonRequiredPriority(priority)) {
      return Result.badRequiredStrength;
    }

    final constraint = Constraint(
      Expression(<Term>[Term(variable, 1)], 0),
      Relation.equalTo,
    )..priority = priority;

    // ignore: unused_local_variable
    final result = addConstraint(constraint);
    assert(result == Result.success);

    final info = _EditInfo()
      ..tag = _constraints[constraint]
      ..constraint = constraint
      ..constant = 0.0;

    _edits[variable] = info;

    return Result.success;
  }

  /// Attempt the remove the list of edit [Variable] from the solver. Either
  /// all the specified edit variables are removed or none.
  ///
  /// Check the [Result] returned to make sure the operation succeeded. Any
  /// errors will be reported via the `message` property on the [Result].
  ///
  /// Possible [Result]s:
  ///
  /// * [Result.success]: The edit variables were successfully removed from the
  ///   [Solver].
  /// * [Result.unknownEditVariable]: One of more edit variables were not
  ///   already present in the solver.
  Result removeEditVariables(List<Variable> variables) {
    Result _applier(v) => removeEditVariable(v);
    Result _undoer(v) => addEditVariable(v, _edits[v].constraint.priority);

    return _bulkEdit(variables, _applier, _undoer);
  }

  /// Attempt to remove the specified edit [Variable] from the solver.
  ///
  /// Check the [Result] returned to make sure the operation succeeded. Any
  /// errors will be reported via the `message` property on the [Result].
  ///
  /// Possible [Result]s:
  ///
  /// * [Result.success]: The edit variable was successfully removed from the
  ///   solver.
  /// * [Result.unknownEditVariable]: The edit variable was not present in the
  ///   solver. There was nothing to remove.
  Result removeEditVariable(Variable variable) {
    final info = _edits[variable];
    if (info == null) {
      return Result.unknownEditVariable;
    }

    // ignore: unused_local_variable
    final result = removeConstraint(info.constraint);
    assert(result == Result.success);

    _edits.remove(variable);
    return Result.success;
  }

  /// Returns whether the given edit [Variable] is present in the solver.
  bool hasEditVariable(Variable variable) => _edits.containsKey(variable);

  /// Suggest an updated value for the edit variable. The edit variable
  /// must already be added to the solver.
  ///
  /// Suggestions update values of variables within the [Solver] but take into
  /// account all the constraints already present in the [Solver]. Depending
  /// on the constraints, the value of the [Variable] may not actually be the
  /// value specified. The actual value can be read after the next
  /// `flushUpdates` call. Since these updates are merely "suggestions", they
  /// cannot be at `Priority.required`.
  ///
  ///
  /// Check the [Result] returned to make sure the operation succeeded. Any
  /// errors will be reported via the `message` property on the [Result].
  ///
  /// Possible [Result]s:
  ///
  /// * [Result.success]: The suggestion was successfully applied to the
  ///   variable within the solver.
  /// * [Result.unknownEditVariable]: The edit variable was not already present
  ///   in the [Solver]. So the suggestion could not be applied. Add this edit
  ///   variable to the solver and then apply the value again. If you have
  ///   already added the variable to the [Solver], make sure the [Result]
  ///   was `Result.success`.
  Result suggestValueForVariable(Variable variable, double value) {
    if (!_edits.containsKey(variable)) {
      return Result.unknownEditVariable;
    }

    _suggestValueForEditInfoWithoutDualOptimization(_edits[variable], value);

    return _dualOptimize();
  }

  /// Flush the results of solver. The set of all `context` objects associated
  /// with variables in the [Solver] is returned. If a [Variable] does not
  /// contain an associated context, its updates are ignored.
  ///
  /// The addition and removal of constraints and edit variables to and from the
  /// [Solver] as well as the application of suggestions to the added edit
  /// variables leads to the modification of values on a lot of other variables.
  /// External entities that rely on the values of the variables within the
  /// [Solver] can read these updates in one shot by "flushing" out these
  /// updates.
  Set<dynamic> flushUpdates() {
    final updates = HashSet<dynamic>();

    for (final variable in _vars.keys) {
      final symbol = _vars[variable];
      final row = _rows[symbol];

      final updatedValue = row == null ? 0.0 : row.constant;

      if (variable.applyUpdate(updatedValue) && variable.owner != null) {
        final context = variable.owner.context;
        if (context != null) {
          updates.add(context);
        }
      }
    }

    return updates;
  }

  Result _bulkEdit(
    Iterable<dynamic> items,
    _SolverBulkUpdate applier,
    _SolverBulkUpdate undoer,
  ) {
    final applied = <dynamic>[];
    var needsCleanup = false;

    var result = Result.success;

    for (final item in items) {
      result = applier(item);
      if (result == Result.success) {
        applied.add(item);
      } else {
        needsCleanup = true;
        break;
      }
    }

    if (needsCleanup) {
      applied.reversed.forEach(undoer);
    }

    return result;
  }

  _Symbol _symbolForVariable(Variable variable) {
    var symbol = _vars[variable];

    if (symbol != null) {
      return symbol;
    }

    symbol = _Symbol(_SymbolType.external);
    _vars[variable] = symbol;

    return symbol;
  }

  _Row _createRow(Constraint constraint, _Tag tag) {
    final expr = Expression.fromExpression(constraint.expression);
    final row = _Row(expr.constant);

    for (final term in expr.terms) {
      if (!_nearZero(term.coefficient)) {
        final symbol = _symbolForVariable(term.variable);

        final foundRow = _rows[symbol];

        if (foundRow != null) {
          row.insertRow(foundRow, term.coefficient);
        } else {
          row.insertSymbol(symbol, term.coefficient);
        }
      }
    }

    switch (constraint.relation) {
      case Relation.lessThanOrEqualTo:
      case Relation.greaterThanOrEqualTo:
        {
          final coefficient =
              constraint.relation == Relation.lessThanOrEqualTo ? 1.0 : -1.0;

          final slack = _Symbol(_SymbolType.slack);
          tag.marker = slack;
          row.insertSymbol(slack, coefficient);

          if (constraint.priority < Priority.required) {
            final error = _Symbol(_SymbolType.error);
            tag.other = error;
            row.insertSymbol(error, -coefficient);
            _objective.insertSymbol(error, constraint.priority);
          }
        }
        break;
      case Relation.equalTo:
        if (constraint.priority < Priority.required) {
          final errPlus = _Symbol(_SymbolType.error);
          final errMinus = _Symbol(_SymbolType.error);
          tag
            ..marker = errPlus
            ..other = errMinus;
          row..insertSymbol(errPlus, -1)..insertSymbol(errMinus, 1);
          _objective
            ..insertSymbol(errPlus, constraint.priority)
            ..insertSymbol(errMinus, constraint.priority);
        } else {
          final dummy = _Symbol(_SymbolType.dummy);
          tag.marker = dummy;
          row.insertSymbol(dummy);
        }
        break;
    }

    if (row.constant < 0.0) {
      row.reverseSign();
    }

    return row;
  }

  _Symbol _chooseSubjectForRow(_Row row, _Tag tag) {
    for (final symbol in row.cells.keys) {
      if (symbol.type == _SymbolType.external) {
        return symbol;
      }
    }

    if (tag.marker.type == _SymbolType.slack ||
        tag.marker.type == _SymbolType.error) {
      if (row.coefficientForSymbol(tag.marker) < 0.0) {
        return tag.marker;
      }
    }

    if (tag.other.type == _SymbolType.slack ||
        tag.other.type == _SymbolType.error) {
      if (row.coefficientForSymbol(tag.other) < 0.0) {
        return tag.other;
      }
    }

    return _Symbol(_SymbolType.invalid);
  }

  bool _allDummiesInRow(_Row row) {
    for (final symbol in row.cells.keys) {
      if (symbol.type != _SymbolType.dummy) {
        return false;
      }
    }
    return true;
  }

  bool _addWithArtificialVariableOnRow(_Row row) {
    final artificial = _Symbol(_SymbolType.slack);
    _rows[artificial] = _Row.fromRow(row);
    _artificial = _Row.fromRow(row);

    final result = _optimizeObjectiveRow(_artificial);

    if (result.isError) {
      // FIXME(csg): Propagate this up!
      return false;
    }

    final success = _nearZero(_artificial.constant);
    _artificial = _Row(0);

    final foundRow = _rows[artificial];
    if (foundRow != null) {
      _rows.remove(artificial);
      if (foundRow.cells.isEmpty) {
        return success;
      }

      final entering = _anyPivotableSymbol(foundRow);
      if (entering.type == _SymbolType.invalid) {
        return false;
      }

      foundRow.solveForSymbols(artificial, entering);
      _substitute(entering, foundRow);
      _rows[entering] = foundRow;
    }

    for (final row in _rows.values) {
      row.removeSymbol(artificial);
    }
    _objective.removeSymbol(artificial);
    return success;
  }

  Result _optimizeObjectiveRow(_Row objective) {
    var entering = _enteringSymbolForObjectiveRow(objective);
    while (entering.type != _SymbolType.invalid) {
      final leaving = _leavingSymbolForEnteringSymbol(entering);
      assert(leaving != null);

      final row = _rows.remove(leaving)..solveForSymbols(leaving, entering);
      _substitute(entering, row);
      _rows[entering] = row;

      entering = _enteringSymbolForObjectiveRow(objective);
    }
    return Result.success;
  }

  _Symbol _enteringSymbolForObjectiveRow(_Row objective) {
    final cells = objective.cells;

    for (final symbol in cells.keys) {
      if (symbol.type != _SymbolType.dummy && cells[symbol] < 0.0) {
        return symbol;
      }
    }

    return _Symbol(_SymbolType.invalid);
  }

  _Symbol _leavingSymbolForEnteringSymbol(_Symbol entering) {
    var ratio = double.maxFinite;
    _Symbol result;
    _rows.forEach((symbol, row) {
      if (symbol.type != _SymbolType.external) {
        final temp = row.coefficientForSymbol(entering);
        if (temp < 0.0) {
          final tempRatio = -row.constant / temp;
          if (tempRatio < ratio) {
            ratio = tempRatio;
            result = symbol;
          }
        }
      }
    });
    return result;
  }

  void _substitute(_Symbol symbol, _Row row) {
    _rows.forEach((first, second) {
      second.substitute(symbol, row);
      if (first.type != _SymbolType.external && second.constant < 0.0) {
        _infeasibleRows.add(first);
      }
    });
    _objective.substitute(symbol, row);
    if (_artificial != null) {
      _artificial.substitute(symbol, row);
    }
  }

  _Symbol _anyPivotableSymbol(_Row row) {
    for (final symbol in row.cells.keys) {
      if (symbol.type == _SymbolType.slack ||
          symbol.type == _SymbolType.error) {
        return symbol;
      }
    }
    return _Symbol(_SymbolType.invalid);
  }

  void _removeConstraintEffects(Constraint cn, _Tag tag) {
    if (tag.marker.type == _SymbolType.error) {
      _removeMarkerEffects(tag.marker, cn.priority);
    }
    if (tag.other.type == _SymbolType.error) {
      _removeMarkerEffects(tag.other, cn.priority);
    }
  }

  void _removeMarkerEffects(_Symbol marker, double strength) {
    final row = _rows[marker];
    if (row != null) {
      _objective.insertRow(row, -strength);
    } else {
      _objective.insertSymbol(marker, -strength);
    }
  }

  _Symbol _leavingSymbolForMarkerSymbol(_Symbol marker) {
    var r1 = double.maxFinite;
    var r2 = double.maxFinite;

    _Symbol first, second, third;

    _rows.forEach((symbol, row) {
      final c = row.coefficientForSymbol(marker);
      if (c == 0.0) {
        return;
      }
      if (symbol.type == _SymbolType.external) {
        third = symbol;
      } else if (c < 0.0) {
        final r = -row.constant / c;
        if (r < r1) {
          r1 = r;
          first = symbol;
        }
      } else {
        final r = row.constant / c;
        if (r < r2) {
          r2 = r;
          second = symbol;
        }
      }
    });

    return first ?? second ?? third;
  }

  void _suggestValueForEditInfoWithoutDualOptimization(
      _EditInfo info, double value) {
    final delta = value - info.constant;
    info.constant = value;

    {
      var symbol = info.tag.marker;
      var row = _rows[info.tag.marker];

      if (row != null) {
        if (row.add(-delta) < 0.0) {
          _infeasibleRows.add(symbol);
        }
        return;
      }

      symbol = info.tag.other;
      row = _rows[info.tag.other];

      if (row != null) {
        if (row.add(delta) < 0.0) {
          _infeasibleRows.add(symbol);
        }
        return;
      }
    }

    for (final symbol in _rows.keys) {
      final row = _rows[symbol];
      final coeff = row.coefficientForSymbol(info.tag.marker);
      if (coeff != 0.0 &&
          row.add(delta * coeff) < 0.0 &&
          symbol.type != _SymbolType.external) {
        _infeasibleRows.add(symbol);
      }
    }
  }

  Result _dualOptimize() {
    while (_infeasibleRows.isNotEmpty) {
      final leaving = _infeasibleRows.removeLast();
      final row = _rows[leaving];

      if (row != null && row.constant < 0.0) {
        final entering = _dualEnteringSymbolForRow(row);

        assert(entering.type != _SymbolType.invalid);

        _rows.remove(leaving);

        row.solveForSymbols(leaving, entering);
        _substitute(entering, row);
        _rows[entering] = row;
      }
    }
    return Result.success;
  }

  _Symbol _dualEnteringSymbolForRow(_Row row) {
    _Symbol entering;

    var ratio = double.maxFinite;

    final rowCells = row.cells;

    for (final symbol in rowCells.keys) {
      final value = rowCells[symbol];

      if (value > 0.0 && symbol.type != _SymbolType.dummy) {
        final coeff = _objective.coefficientForSymbol(symbol);
        final r = coeff / value;
        if (r < ratio) {
          ratio = r;
          entering = symbol;
        }
      }
    }

    return entering ?? _Symbol(_SymbolType.invalid);
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    const separator = '\n~~~~~~~~~';

    buffer
      // Objective
      ..writeln('$separator Objective')
      ..writeln(_objective.toString())
      // Tableau
      ..writeln('$separator Tableau');

    _rows.forEach((symbol, row) {
      buffer.writeln('$symbol | $row');
    });

    // Infeasible
    buffer.writeln('$separator Infeasible');
    _infeasibleRows.forEach(buffer.writeln);

    // Variables
    buffer.writeln('$separator Variables');
    _vars.forEach((variable, symbol) {
      buffer.writeln('$variable = $symbol');
    });

    // Edit Variables
    buffer.writeln('$separator Edit Variables');
    _edits.forEach((variable, editinfo) {
      buffer.writeln(variable);
    });

    // Constraints
    buffer.writeln('$separator Constraints');
    _constraints.forEach((constraint, tag) {
      buffer.writeln(constraint);
    });

    return buffer.toString();
  }
}
