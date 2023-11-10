/*
 * Copyright 2015 Workiva Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

part of r_tree;

/// A [Node] that is not a leaf end of the [RTree]. These are created automatically
/// by [RTree] when inserting/removing items from the tree.
class NonLeafNode<E> extends Node<E> {
  late final List<Node<E>> _childNodes;
  @override
  List<Node<E>> get children => _childNodes;

  NonLeafNode(int branchFactor, {List<Node<E>>? initialChildNodes}) : super(branchFactor) {
    if (initialChildNodes != null) {
      if (initialChildNodes.length > branchFactor) {
        throw ArgumentError('too many items');
      }
      _childNodes = initialChildNodes;
      updateBoundingRect();
    } else {
      _childNodes = [];
    }
  }

  @override
  Node<E> createNewNode() {
    return NonLeafNode<E>(branchFactor);
  }

  @override
  Iterable<RTreeDatum<E>> search(Rectangle searchRect, bool Function(E item)? shouldInclude) {
    final overlappingLeafs = <RTreeDatum<E>>[];

    for (final childNode in _childNodes) {
      if (childNode.rect.overlaps(searchRect)) {
        overlappingLeafs.addAll(childNode.search(searchRect, shouldInclude));
      }
    }

    return overlappingLeafs;
  }

  @override
  Node<E>? insert(RTreeDatum<E> item) {
    include(item);

    final bestNode = _getBestNodeForInsert(item);
    final splitNode = bestNode.insert(item);

    if (splitNode != null) {
      addChild(splitNode);
    }

    return splitIfNecessary();
  }

  @override
  void remove(RTreeDatum<E> item) {
    final childrenToRemove = <Node<E>>[];

    for (final childNode in _childNodes) {
      if (childNode.rect.overlaps(item.rect)) {
        childNode.remove(item);

        if (childNode.size == 0) {
          childrenToRemove.add(childNode);
        }
      }
    }

    for (final child in childrenToRemove) {
      removeChild(child);
    }

    _updateHeightAndBounds();
  }

  @override
  void addChild(Node<E> child) {
    super.addChild(child);
    child.parent = this;
  }

  @override
  void removeChild(Node<E> child) {
    super.removeChild(child);
    child.parent = null;

    _updateHeightAndBounds();
  }

  @override
  void clearChildren() {
    _childNodes.clear();
    _minimumBoundingRect = noMBR;
  }

  Node<E> _getBestNodeForInsert(RTreeDatum<E> item) {
    var bestNode = _childNodes[0];
    var bestCost = bestNode.expansionCost(item);

    for (var i = 1; i < _childNodes.length; i++) {
      final child = _childNodes[i];
      final tentativeCost = child.expansionCost(item);
      if (tentativeCost < bestCost) {
        bestCost = tentativeCost;
        bestNode = child;
      }
    }

    return bestNode;
  }

  void _updateHeightAndBounds() {
    var maxChildHeight = 0;
    for (final childNode in _childNodes) {
      maxChildHeight = max(maxChildHeight, childNode.height);
    }
    height = 1 + maxChildHeight;

    updateBoundingRect();
  }
}
