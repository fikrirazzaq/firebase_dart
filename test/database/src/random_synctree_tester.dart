import 'dart:math';

import 'package:firebase_dart/src/database/impl/data_observer.dart';
import 'package:firebase_dart/src/database/impl/operations/tree.dart';
import 'package:firebase_dart/src/database/impl/query_spec.dart';
import 'package:firebase_dart/src/database/impl/utils.dart';
import 'package:firebase_dart/src/database/impl/synctree.dart';
import 'package:firebase_dart/src/database/impl/tree.dart';
import 'package:firebase_dart/src/database/impl/treestructureddata.dart';
import 'package:logging/logging.dart';
import 'package:sortedmap/sortedmap.dart';

final _logger = Logger('firebase.test.random_synctree');

class RandomSyncTreeTester {
  SyncTree _syncTree;

  SyncTree get syncTree => _syncTree;

  static Logger get logger => _logger;

  final RandomGenerator random;

  final double listenProbability;

  final double userOperationProbability;

  final double serverOperationProbability;

  final double serverListenResponseProbability;

  final double serverAckProbability;

  final double revertProbability;

  int _currentWriteId = 0;

  final List<QuerySpec> outstandingListens = [];

  TreeStructuredData _currentServerState = TreeStructuredData();

  final List<MapEntry<int, TreeOperation>> outstandingWrites = [];

  TreeStructuredData get currentServerState => _currentServerState;

  RandomSyncTreeTester(
      {int seed,
      this.listenProbability = 0.1,
      this.userOperationProbability = 0.1,
      this.serverListenResponseProbability = 0.1,
      this.serverAckProbability = 0.9,
      this.revertProbability = 0.2,
      this.serverOperationProbability = 0.1})
      : random =
            RandomGenerator(seed ?? DateTime.now().millisecondsSinceEpoch) {
    _syncTree = SyncTree('test:///', RemoteListenerRegistrar.fromCallbacks(
        remoteRegister: (path, query, tag) async {
      outstandingListens.add(QuerySpec(path, query));
    }));
  }

  void _generateUserListen() {
    _logger.fine('generate user listen');
    var query = random.nextQuerySpec();
    _logger.fine('* $query');

    syncTree.addEventListener('value', query.path, query.params, (event) {});
  }

  void _generateUserOperation() {
    _logger.fine('generate user operation');
    var operation = random.nextOperation();
    _logger.fine('* $operation');

    var taggedOperation = MapEntry(_currentWriteId++, operation);
    syncTree.applyUserOperation(taggedOperation.value, taggedOperation.key);
    outstandingWrites.add(taggedOperation);
  }

  void _handleOutstandingListen() {
    if (outstandingListens.isEmpty) return;
    _logger.fine('handle outstanding listen');
    var query = outstandingListens.removeAt(0);
    _logger.fine('* $query');
    var v = _currentServerState.getChild(query.path);
    v = v.withFilter(query.params);
    syncTree.applyServerOperation(
        TreeOperation(query.path, Overwrite(v)), query.params);
  }

  void _handleOutstandingWrite() {
    if (outstandingWrites.isEmpty) return;
    _logger.fine('handle outstanding write');

    var op = outstandingWrites.removeAt(0);
    _logger.fine('* $op');
    var path = op.value.path;
    var isEmptyPriorityError = path.isNotEmpty &&
        path.last.isPriorityChildName &&
        _currentServerState.getChild(path.parent).isEmpty;

    if (random.nextDouble() < revertProbability || isEmptyPriorityError) {
      syncTree.applyAck(op.value.path, op.key, false);
    } else {
      _currentServerState = op.value.apply(_currentServerState);
      _notifyServerOperation(op.value.path);
      syncTree.applyAck(op.value.path, op.key, true);
    }
  }

  void _notifyServerOperation(Path path) {
    var tree = syncTree.root.subtree(path);
    if (tree != null) {
      tree.forEachNode((subPath, node) {
        var fullPath = Path<Name>.from([...path, ...subPath]);
        node.views.forEach((params, view) {
          syncTree.applyServerOperation(
              TreeOperation.overwrite(fullPath,
                  currentServerState.getChild(fullPath).withFilter(params)),
              params);
        });
      });
    }
    var p = path.parent;
    while (p != null) {
      var tree = syncTree.root.subtree(p);
      if (tree != null) {
        var node = tree.value;
        node.views.forEach((params, view) {
          syncTree.applyServerOperation(
              TreeOperation.overwrite(
                  p, currentServerState.getChild(p).withFilter(params)),
              params);
        });
      }
      p = p.parent;
    }
  }

  void _generateServerOperation() {
    _logger.fine('generate server operation');
    var op = random.nextOperation();
    _logger.fine('* $op');
    var newState = op.apply(_currentServerState);
    if (newState == _currentServerState) return;
    _currentServerState = newState;
    _notifyServerOperation(op.path);
  }

  void checkAllViewsComplete() {
    if (outstandingListens.isNotEmpty || outstandingWrites.isNotEmpty) {
      throw StateError(
          'Should call flush prior to checking views for completeness');
    }
    syncTree.root.forEachNode((path, node) {
      node.views.forEach((params, view) {
        if (!view.data.localVersion.isComplete) {
          throw StateError('Local version should be complete');
        }
        if (!view.data.serverVersion.isComplete) {
          throw StateError('Server version should be complete');
        }
      });
    });
  }

  void checkServerVersions() {
    syncTree.root.forEachNode((path, node) {
      node.views.forEach((params, view) {
        if (view.data.serverVersion.isComplete) {
          // complete data should match with value on server
          var serverValue =
              currentServerState.getChild(path).withFilter(params);
          var serverView = view.data.serverVersion.value;
          if (serverValue != serverView) {
            throw StateError('SyncTree has an incorrect view of the server');
          }
        }
      });
    });
  }

  void checkLocalVersions() {
    var v = currentServerState;
    for (var w in outstandingWrites) {
      v = w.value.apply(v);
    }

    syncTree.root.forEachNode((path, node) {
      node.views.forEach((params, view) {
        if (view.data.localVersion.isComplete) {
          // complete data should match with value on server
          var serverValue = v.getChild(path).withFilter(params);
          var serverView = view.data.localVersion.value;
          if (serverValue != serverView) {
            throw StateError('SyncTree has an incorrect local version');
          }
        }
      });
    });
  }

  void next() {
    if (random.nextDouble() < listenProbability) {
      _generateUserListen();
    } else if (random.nextDouble() < userOperationProbability) {
      _generateUserOperation();
    } else if (random.nextDouble() < serverListenResponseProbability) {
      _handleOutstandingListen();
    } else if (random.nextDouble() < serverAckProbability) {
      _handleOutstandingWrite();
    } else if (random.nextDouble() < serverOperationProbability) {
      _generateServerOperation();
    }
  }

  void flush() {
    while (outstandingListens.isNotEmpty) {
      _handleOutstandingListen();
    }
    while (outstandingWrites.isNotEmpty) {
      _handleOutstandingWrite();
    }
  }
}

extension SyncTreeX on SyncTree {
  void applyUserOperation(TreeOperation operation, int writeId) {
    var op = operation.nodeOperation;
    if (op is Merge) {
      applyUserMerge(
          operation.path,
          {
            for (var o in op.overwrites)
              o.path: (o.nodeOperation as Overwrite).value
          },
          writeId);
    } else if (op is SetPriority) {
      applyUserOverwrite(operation.path.child(Name('.priority')),
          TreeStructuredData.leaf(op.value), writeId);
    } else {
      applyUserOverwrite(operation.path, (op as Overwrite).value, writeId);
    }
  }
}

class RandomGenerator {
  final Random _random;

  final RandomGeneratorParameters parameters;

  RandomGenerator([int seed])
      : _random = Random(seed),
        parameters = RandomGeneratorParameters() {
    print('Random seed $seed');
  }

  Name nextKey() {
    if (_random.nextDouble() < parameters.indexKeyProbability) {
      return Name('index-key');
    } else {
      return Name('key-${_random.nextInt(parameters.maxKeyValues)}');
    }
  }

  Path<Name> nextPath(int maxDepth) {
    var depth = _random.nextInt(maxDepth);

    return Path.from([...Iterable.generate(depth, (_) => nextKey())]);
  }

  TreeStructuredDataOrdering nextOrdering() {
    if (_random.nextDouble() < parameters.orderByKeyProbability) {
      return TreeStructuredDataOrdering.byKey();
    } else if (_random.nextDouble() < parameters.orderByPriorityProbability) {
      return TreeStructuredDataOrdering.byPriority();
    } else if (_random.nextDouble() < parameters.orderByValueProbability) {
      return TreeStructuredDataOrdering.byValue();
    } else {
      return TreeStructuredDataOrdering.byChild('index-key');
    }
  }

  QuerySpec nextQuerySpec() {
    return QuerySpec(
      nextPath(parameters.maxListenDepth),
      nextQueryParams(),
    );
  }

  QueryFilter nextQueryParams() {
    if (nextDouble() < parameters.defaultParamsProbability) {
      return QueryFilter();
    } else {
      var ordering = nextOrdering();
      return QueryFilter(
          ordering: ordering,
          limit: nextBool() ? null : nextInt(30) + 1,
          reversed: nextBool(),
          validInterval:
              nextKeyValueInterval(keyOnly: ordering is KeyOrdering));
    }
  }

  Value nextValue({bool allowNull = false}) {
    var randValue = nextDouble();
    if (allowNull && randValue < 0.2) {
      return null;
    } else if (randValue < 0.4) {
      return Value.bool(nextBool());
    } else if (randValue < 0.6) {
      return Value.string('string-${nextInt(1 << 31)}');
    } else if (randValue < 0.8) {
      return Value.num(nextDouble());
    } else {
      return Value.num(nextInt(1 << 31));
    }
  }

  KeyValueInterval nextKeyValueInterval({bool keyOnly = false}) {
    var startValue =
        nextBool() || keyOnly ? null : TreeStructuredData.leaf(nextValue());
    var endValue =
        nextBool() || keyOnly ? null : TreeStructuredData.leaf(nextValue());
    if (startValue != null &&
        endValue != null &&
        Comparable.compare(startValue, endValue) > 0) {
      var v = startValue;
      startValue = endValue;
      endValue = v;
    }

    var startKey = startValue == null || nextBool() ? null : nextKey();
    var endKey = endValue == null || nextBool() ? null : nextKey();
    if (startKey != null &&
        endKey != null &&
        Comparable.compare(startKey, endKey) > 0) {
      var v = startKey;
      startKey = endKey;
      endKey = v;
    }
    return KeyValueInterval(startKey, startValue, endKey, endValue);
  }

  double nextDouble() => _random.nextDouble();

  bool nextBool() => _random.nextBool();

  int nextInt(int max) => _random.nextInt(max);

  Merge nextMerge(int currentDepth) {
    var numMergeNodes = nextInt(parameters.maxMergeSize) + 1;
    return Merge({
      for (var i = 0; i < numMergeNodes; i++)
        Path.from([nextKey()]): nextTreeValue(currentDepth + 1)
    });
  }

  TreeStructuredData nextTreeValue(int currentDepth, {bool allowNull = true}) {
    if (currentDepth >= parameters.maxDepth) {
      return TreeStructuredData.leaf(nextValue(allowNull: allowNull));
    } else {
      var randValue = _random.nextDouble();
      if (allowNull && randValue < 0.2) {
        return TreeStructuredData();
      } else if (randValue < 0.4) {
        return TreeStructuredData.leaf(nextValue(allowNull: allowNull));
      } else {
        var numChildren = 1 +
            _random.nextInt(currentDepth == 0
                ? parameters.maxTopChildren
                : parameters.maxOtherChildren);
        return TreeStructuredData.nonLeaf({
          for (var i = 0; i < numChildren; i++)
            nextKey(): nextTreeValue(currentDepth + 1, allowNull: false)
        }, nextValue());
      }
    }
  }

  Overwrite nextOverwrite(int currentDepth) {
    return Overwrite(nextTreeValue(currentDepth));
  }

  SetPriority nextSetPriority() {
    return SetPriority(nextValue(allowNull: true));
  }

  Operation nextNodeOperation(int currentDepth) {
    if (nextDouble() < parameters.setPriorityProbability) {
      return nextSetPriority();
    } else if (nextDouble() < parameters.mergeProbability) {
      return nextMerge(currentDepth);
    } else {
      return nextOverwrite(currentDepth);
    }
  }

  TreeOperation nextOperation() {
    var path = nextPath(parameters.maxDepth);
    var op = nextNodeOperation(path.length);

    return TreeOperation(path, op);
  }
}

class RandomGeneratorParameters {
  final int maxKeyValues;

  final double setPriorityProbability;

  final double indexKeyProbability;

  final double orderByKeyProbability;

  final double orderByPriorityProbability;
  final double orderByValueProbability;

  final double defaultParamsProbability;

  final double mergeProbability;

  final int maxListenDepth;

  final int maxMergeSize;

  final int maxDepth;

  final int maxTopChildren;

  final int maxOtherChildren;

  RandomGeneratorParameters(
      {this.defaultParamsProbability = 0.5,
      this.orderByKeyProbability = 0.1,
      this.orderByPriorityProbability = 0.1,
      this.orderByValueProbability = 0.1,
      this.maxKeyValues = 100,
      this.setPriorityProbability = 0.1,
      this.indexKeyProbability = 0.1,
      this.maxListenDepth = 3,
      this.mergeProbability = 0.3,
      this.maxMergeSize = 5,
      this.maxDepth = 5,
      this.maxOtherChildren = 3,
      this.maxTopChildren = 10});
}
