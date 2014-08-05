// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.completion.computer;

import 'dart:async';

import 'package:analysis_services/completion/completion_suggestion.dart';
import 'package:analysis_services/search/search_engine.dart';
import 'package:analysis_services/src/completion/top_level_computer.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart';

/**
 * The base class for computing code completion suggestions.
 */
abstract class CompletionComputer {

  /**
   * Computes [CompletionSuggestion]s for the specified position in the source.
   */
  Future<List<CompletionSuggestion>> compute();
}

/**
 * Manages `CompletionComputer`s for a given completion request.
 */
abstract class CompletionManager {

  /**
   * Create a manager for the given request.
   */
  static CompletionManager create(Source source, int offset,
      SearchEngine searchEngine) {
    if (AnalysisEngine.isDartFileName(source.shortName)) {
      return new DartCompletionManager(source, offset, searchEngine);
    }
    return new NoOpCompletionManager(source, offset);
  }

  StreamController<CompletionResult> controller;

  /**
   * Generate a stream of code completion results.
   */
  Stream<CompletionResult> results() {
    controller = new StreamController<CompletionResult>(onListen: () {
      scheduleMicrotask(compute);
    });
    return controller.stream;
  }

  /**
   * Compute completion results and append them to the stream.
   * Clients should not call this method directly as it is automatically called
   * when a client listens to the stream returned by [results].
   */
  void compute();
}

/**
 * Code completion result generated by an [CompletionManager].
 */
class CompletionResult {

  /**
   * The length of the text to be replaced if the remainder of the identifier
   * containing the cursor is to be replaced when the suggestion is applied
   * (that is, the number of characters in the existing identifier).
   */
  final int replacementLength;

  /**
   * The offset of the start of the text to be replaced. This will be different
   * than the offset used to request the completion suggestions if there was a
   * portion of an identifier before the original offset. In particular, the
   * replacementOffset will be the offset of the beginning of said identifier.
   */
  final int replacementOffset;

  /**
   * The suggested completions.
   */
  final List<CompletionSuggestion> suggestions;

  /**
   * `true` if this is that last set of results that will be returned
   * for the indicated completion.
   */
  final bool last;

  CompletionResult(this.replacementOffset, this.replacementLength,
      this.suggestions, this.last);
}

/**
 * Manages code completion for a given Dart file completion request.
 */
class DartCompletionManager extends CompletionManager {
  final Source source;
  final int offset;
  final SearchEngine searchEngine;

  DartCompletionManager(this.source, this.offset, this.searchEngine);

  @override
  void compute() {
    var computer = new TopLevelComputer(searchEngine);
    computer.compute().then((List<CompletionSuggestion> suggestions) {
      controller.add(new CompletionResult(offset, 0, suggestions, true));
    });
  }
}

class NoOpCompletionManager extends CompletionManager {
  final Source source;
  final int offset;

  NoOpCompletionManager(this.source, this.offset);

  @override
  void compute() {
    controller.add(new CompletionResult(offset, 0, [], true));
  }
}