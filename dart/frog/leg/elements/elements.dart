// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library('elements');

#import('../tree/tree.dart');
#import('../scanner/scannerlib.dart');
#import('../leg.dart');  // TODO(karlklose): we only need type.
#import('../util/util.dart');

// TODO(ahe): Better name, better abstraction...
interface Canceler {
  void cancel([String reason, node, token, instruction]);
}

// TODO(ahe): Better name, better abstraction...
interface Logger {
  void log(message);
}

class ElementKind {
  final String id;

  const ElementKind(String this.id);

  static final ElementKind VARIABLE = const ElementKind('variable');
  static final ElementKind PARAMETER = const ElementKind('parameter');
  static final ElementKind FUNCTION = const ElementKind('function');
  static final ElementKind CLASS = const ElementKind('class');
  static final ElementKind FOREIGN = const ElementKind('foreign');
  static final ElementKind CONSTRUCTOR = const ElementKind('constructor');
  static final ElementKind FIELD = const ElementKind('field');
  static final ElementKind VARIABLE_LIST = const ElementKind('variable_list');
  static final ElementKind FIELD_LIST = const ElementKind('field_list');
  static final ElementKind CONSTRUCTOR_BODY =
      const ElementKind('constructor_body');

  toString() => id;
}

class Element implements Hashable {
  final SourceString name;
  final ElementKind kind;
  final Element enclosingElement;
  abstract Node parseNode(Canceler canceler, Logger logger);
  abstract Type computeType(Compiler compiler, Types types);
  bool isMember() =>
      enclosingElement !== null && enclosingElement.kind == ElementKind.CLASS;
  bool isInstanceMember() => false;

  const Element(this.name, this.kind, this.enclosingElement);

  // TODO(kasperl): This is a very bad hash code for the element and
  // there's no reason why two elements with the same name should have
  // the same hash code. Replace this with a simple id in the element?
  int hashCode() => name.hashCode();

  toString() => '$kind($name)';
}

class VariableElement extends Element {
  final VariableListElement variables;
  Modifiers get modifiers() => variables.modifiers;

  VariableElement(SourceString name,
                  VariableListElement this.variables,
                  ElementKind kind,
                  Element enclosing)
    : super(name, kind, enclosing);

  Node parseNode(Canceler canceler, Logger logger) {
    return variables.parseNode(canceler, logger);
  }

  Type computeType(Compiler compiler, types) {
    return variables.computeType(compiler, types);
  }

  Type get type() => variables.type;

  bool isInstanceMember() {
    return isMember() && !modifiers.isStatic();
  }
}

// This element represents a list of variable or field declaration.
// It contains the node, and the type. A [VariableElement] always
// references its [VariableListElement]. It forwards its
// [computeType] and [parseNode] methods to this element.
class VariableListElement extends Element {
  VariableDefinitions node;
  Type type;
  final Modifiers modifiers;

  VariableListElement(ElementKind kind,
                      Modifiers this.modifiers,
                      Element enclosing)
    : super(null, kind, enclosing);

  VariableListElement.node(VariableDefinitions node,
                           ElementKind kind,
                           Element enclosing)
    : super(null, kind, enclosing),
      this.node = node,
      this.modifiers = node.modifiers;

  VariableDefinitions parseNode(Canceler canceler, Logger logger) {
    return node;
  }

  Type computeType(Compiler compiler, types) {
    if (type != null) return type;
    type = getType(parseNode(compiler, compiler).type, compiler, types);
    return type;
  }
}

class ForeignElement extends Element {
  ForeignElement(SourceString name) : super(name, ElementKind.FOREIGN, null);

  Type computeType(Compiler compiler, types) {
    return types.dynamicType;
  }

  parseNode(compiler, types) {
    throw "internal error: ForeignElement has no node";
  }
}

/**
 * TODO(ngeoffray): Remove this method in favor of using the universe.
 *
 * Return the type referred to by the type annotation. This method
 * accepts annotations with 'typeName == null' to indicate a missing
 * annotation.
 */
Type getType(TypeAnnotation typeAnnotation, compiler, types) {
  if (typeAnnotation == null || typeAnnotation.typeName == null) {
    return types.dynamicType;
  }
  final SourceString name = typeAnnotation.typeName.source;
  Element element = compiler.universe.find(name);
  if (element !== null && element.kind === ElementKind.CLASS) {
    // TODO(karlklose): substitute type parameters.
    return element.computeType(compiler, types);
  }
  return types.lookup(name);
}

class FunctionElement extends Element {
  Link<Element> parameters;
  FunctionExpression node;
  Type type;
  final Modifiers modifiers;

  FunctionElement(SourceString name,
                  ElementKind kind,
                  Modifiers this.modifiers,
                  Element enclosing)
    : super(name, kind, enclosing);
  FunctionElement.node(FunctionExpression node,
                       ElementKind kind,
                       Modifiers this.modifiers,
                       Element enclosing)
    : super(node.name.asIdentifier().source, kind, enclosing),
      this.node = node;

  bool isInstanceMember() {
    return isMember()
           && kind != ElementKind.CONSTRUCTOR
           && !modifiers.isStatic();
  }

  FunctionType computeType(Compiler compiler, types) {
    if (type != null) return type;
    if (parameters == null) compiler.resolveSignature(this);
    FunctionExpression node =
        compiler.parser.measure(() => parseNode(compiler, compiler));
    Type returnType = getType(node.returnType, compiler, types);
    if (returnType === null) compiler.cancel('unknown type ${node.returnType}');

    LinkBuilder<Type> parameterTypes = new LinkBuilder<Type>();
    for (Link<Element> link = parameters; !link.isEmpty(); link = link.tail) {
      parameterTypes.addLast(link.head.computeType(compiler, types));
    }
    type = new FunctionType(returnType, parameterTypes.toLink(), this);
    return type;
  }

  Node parseNode(Canceler canceler, Logger logger) => node;
}

class ConstructorBodyElement extends FunctionElement {
  FunctionElement constructor;

  ConstructorBodyElement(FunctionElement constructor)
      : this.constructor = constructor,
        super(constructor.name,
              ElementKind.CONSTRUCTOR_BODY,
              null,
              constructor.enclosingElement) {
    assert(constructor.node !== null);
    this.parameters = constructor.parameters;
    this.node = constructor.node;
    this.type = constructor.type;
  }

  bool isInstanceMember() => true;

  FunctionType computeType(Compiler compiler, types) { unreachable(); }
  Node parseNode(Canceler canceler, Logger logger) { unreachable(); }
}

class SynthesizedConstructorElement extends FunctionElement {
  SynthesizedConstructorElement(Element enclosing)
    : super(enclosing.name, ElementKind.CONSTRUCTOR, null, enclosing) {
    parameters = const EmptyLink<Element>();
  }

  FunctionType computeType(Compiler compiler, types) {
    if (type != null) return type;
    type = new FunctionType(types.voidType, const EmptyLink<Type>(), this);
    return type;
  }

  Node parseNode(Canceler canceler, Logger logger) {
    if (node != null) return node;
    node = new FunctionExpression(
        new Identifier.synthetic(''),
        new NodeList.empty(),
        new Block(new NodeList.empty()),
        null, null, null);
    return node;
  }
}

class ClassElement extends Element {
  Type type;
  Type supertype;
  Link<Element> members = const EmptyLink<Element>();
  Link<Type> interfaces = const EmptyLink<Type>();
  bool isResolved = false;
  ClassNode node;
  // backendMembers are members that have been added by the backend to simplify
  // compilation. They don't have any user-side counter-part.
  Link<Element> backendMembers = const EmptyLink<Element>();
  SynthesizedConstructorElement synthesizedConstructor;

  ClassElement(SourceString name) : super(name, ElementKind.CLASS, null);

  void addMember(Element element) {
    members = members.prepend(element);
  }

  Type computeType(compiler, types) {
    if (type === null) {
      type = new SimpleType(name, this);
    }
    return type;
  }

  ClassElement resolve(Compiler compiler) {
    if (!isResolved) {
      compiler.resolveType(this);
      isResolved = true;
    }
    return this;
  }

  Element lookupLocalElement(SourceString name, bool matches(Element)) {
    // TODO(karlklose): replace with more efficient solution.
    for (Link<Element> link = members;
         link !== null && !link.isEmpty();
         link = link.tail) {
      Element element = link.head;
      if (matches(element)) return element;
    }
    return null;
  }

  Element lookupLocalMember(SourceString name) {
    bool matches(Element element) {
      return element.name == name
             && element.kind != ElementKind.CONSTRUCTOR;
    }
    return lookupLocalElement(name, matches);
  }

  Element lookupConstructor(SourceString name) {
    bool matches(Element element) {
      return element.name == name
             && element.kind == ElementKind.CONSTRUCTOR;
    }
    return lookupLocalElement(name, matches);
  }

  // TODO(ngeoffray): Implement these.
  bool canHaveDefaultConstructor() => true;

  SynthesizedConstructorElement getSynthesizedConstructor() {
    if (synthesizedConstructor === null && canHaveDefaultConstructor()) {
      synthesizedConstructor = new SynthesizedConstructorElement(this);
    }
    return synthesizedConstructor;
  }

  parseNode(compiler, types) => node;

  /**
   * Returns the super class, if any.
   *
   * The returned element may not be resolved yet.
   */
  ClassElement get superClass() {
    assert(isResolved);
    return supertype === null ? null : supertype.element;
  }
}

class Elements {
  static bool isInstanceField(Element element) {
    return (element !== null)
           && element.isInstanceMember()
           && (element.kind === ElementKind.FIELD);
  }

  static bool isStaticOrTopLevelField(Element element) {
    return (element != null)
           && !element.isInstanceMember()
           && (element.kind === ElementKind.FIELD);
  }

  static bool isInstanceMethod(Element element) {
    return (element != null)
           && element.isInstanceMember()
           && (element.kind === ElementKind.FUNCTION);
  }
}
