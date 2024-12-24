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

import 'dart:math';

import 'package:r_tree/src/r_tree/node.dart';
import 'package:r_tree/src/r_tree/r_tree_datum.dart';

/// A [Node] that is not a leaf end of the tree. These are created automatically
/// when inserting/removing items from the tree.
class NonLeafNode<E> extends Node<E> {
  final List<Node<E>> _childNodes = [];
  @override
  List<Node<E>> get children => _childNodes;

  NonLeafNode(int branchFactor, {List<Node<E>> initialChildNodes = const []}) : super(branchFactor) {
    if (initialChildNodes.length > branchFactor) {
      throw ArgumentError('too many items');
    }

    for (final child in initialChildNodes) {
      addChild(child);
    }
  }

  @override
  Node<E> createNewNode() {
    return NonLeafNode<E>(branchFactor);
  }

  @override
  List<RTreeDatum<E>> getAllItems() {
    final allItems = <RTreeDatum<E>>[];

    for (final childNode in _childNodes) {
      allItems.addAll(childNode.getAllItems());
    }

    return allItems;
  }

  @override
  List<RTreeDatum<E>> search(
    Rectangle searchRect,
    bool Function(E item)? shouldInclude,
  ) {
    // If the search rectangle contains this node's rectangle, then all items in
    // this node should be returned
    if (searchRect.containsRectangle(rect)) return getAllItems();

    final overlappingLeafs = <RTreeDatum<E>>[];

    for (final childNode in _childNodes) {
      if (childNode.rect.intersects(searchRect)) {
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
  bool remove(RTreeDatum<E> item) {
    final childrenToRemove = <Node<E>>[];

    var atLeastOneItemRemoved = false;

    for (final childNode in _childNodes) {
      if (childNode.rect.intersects(item.rect)) {
        if (childNode.remove(item)) {
          atLeastOneItemRemoved = true;

          if (childNode.size == 0) {
            childrenToRemove.add(childNode);
          }
        }
      }
    }

    if (atLeastOneItemRemoved) {
      for (final child in childrenToRemove) {
        removeChild(child);
      }

      _updateHeightAndBounds();
      return true;
    }

    return false;
  }

  @override
  void addChild(Node<E> child) {
    super.addChild(child);
    child.parent = this;
  }

  @override
  bool removeChild(Node<E> child) {
    if (super.removeChild(child)) {
      child.parent = null;

      _updateHeightAndBounds();

      return true;
    }

    return false;
  }

  @override
  void clearChildren() {
    super.clearChildren();
    _childNodes.clear();
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
