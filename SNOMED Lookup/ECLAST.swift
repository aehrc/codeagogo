import Foundation

// MARK: - AST Node Protocol

/// Base protocol for all ECL AST nodes.
protocol ECLNode {
    /// Accept a visitor for traversal.
    func accept<V: ECLVisitor>(_ visitor: V) -> V.Result
}

// MARK: - Expression Constraint (Root)

/// The root node of an ECL expression.
///
/// An expression constraint can be a compound expression, refined expression,
/// or a simple sub-expression.
indirect enum ECLExpression: ECLNode {
    case compound(CompoundExpression)
    case refined(RefinedExpression)
    case subExpression(SubExpression)

    func accept<V: ECLVisitor>(_ visitor: V) -> V.Result {
        visitor.visitExpression(self)
    }
}

// MARK: - Compound Expression

/// A binary operation combining two expressions.
///
/// Example: `<< 19829001 AND << 301867009`
struct CompoundExpression: ECLNode {
    enum Operator: String {
        case and = "AND"
        case or = "OR"
        case minus = "MINUS"
    }

    let left: ECLExpression
    let op: Operator
    let right: ECLExpression

    func accept<V: ECLVisitor>(_ visitor: V) -> V.Result {
        visitor.visitCompound(self)
    }
}

// MARK: - Refined Expression

/// An expression with attribute refinements.
///
/// Example: `<< 404684003: 363698007 = << 39057004`
struct RefinedExpression: ECLNode {
    let expression: SubExpression
    let refinement: Refinement

    func accept<V: ECLVisitor>(_ visitor: V) -> V.Result {
        visitor.visitRefined(self)
    }
}

// MARK: - Sub-Expression

/// A basic expression unit with optional constraint operator.
///
/// Example: `<< 404684003 |Clinical finding|`
struct SubExpression: ECLNode {
    let constraintOp: ConstraintOperator?
    let focusConcept: FocusConcept
    let filters: [Filter]

    func accept<V: ECLVisitor>(_ visitor: V) -> V.Result {
        visitor.visitSubExpression(self)
    }
}

// MARK: - Constraint Operators

/// Constraint operators that define the scope of a concept reference.
enum ConstraintOperator: String {
    case descendantOf = "<"
    case descendantOrSelfOf = "<<"
    case childOf = "<!"
    case childOrSelfOf = "<<!"
    case ancestorOf = ">"
    case ancestorOrSelfOf = ">>"
    case parentOf = ">!"
    case parentOrSelfOf = ">>!"
    case memberOf = "^"
}

// MARK: - Focus Concept

/// The focus concept of an expression.
indirect enum FocusConcept: ECLNode {
    case concept(ConceptReference)
    case wildcard
    case nested(ECLExpression)
    case memberOf(FocusConcept) // ^refset

    func accept<V: ECLVisitor>(_ visitor: V) -> V.Result {
        visitor.visitFocusConcept(self)
    }
}

// MARK: - Concept Reference

/// A reference to a SNOMED CT concept by ID and optional term.
///
/// Example: `404684003 |Clinical finding|`
struct ConceptReference: ECLNode {
    let sctId: String
    let term: String?

    func accept<V: ECLVisitor>(_ visitor: V) -> V.Result {
        visitor.visitConceptReference(self)
    }
}

// MARK: - Refinement

/// Attribute refinements on an expression.
struct Refinement: ECLNode {
    let items: [RefinementItem]

    func accept<V: ECLVisitor>(_ visitor: V) -> V.Result {
        visitor.visitRefinement(self)
    }
}

/// An item in a refinement (attribute or attribute group).
enum RefinementItem: ECLNode {
    case attribute(Attribute)
    case attributeGroup(AttributeGroup)
    case conjunction([RefinementItem]) // items joined by comma
    case disjunction([RefinementItem]) // items joined by OR

    func accept<V: ECLVisitor>(_ visitor: V) -> V.Result {
        visitor.visitRefinementItem(self)
    }
}

// MARK: - Attribute

/// An attribute constraint.
///
/// Example: `363698007 |Finding site| = << 39057004`
struct Attribute: ECLNode {
    let cardinality: Cardinality?
    let isReverse: Bool
    let name: AttributeName
    let comparator: Comparator
    let value: AttributeValue

    func accept<V: ECLVisitor>(_ visitor: V) -> V.Result {
        visitor.visitAttribute(self)
    }
}

/// The name part of an attribute.
enum AttributeName: ECLNode {
    case concept(ConceptReference)
    case wildcard
    case nested(ECLExpression)

    func accept<V: ECLVisitor>(_ visitor: V) -> V.Result {
        visitor.visitAttributeName(self)
    }
}

/// Comparison operators for attributes.
enum Comparator: String {
    case equals = "="
    case notEquals = "!="
    case lessThanOrEquals = "<="
    case greaterThanOrEquals = ">="
    case lessThan = "<"
    case greaterThan = ">"
}

/// The value part of an attribute.
indirect enum AttributeValue: ECLNode {
    case expression(ECLExpression)
    case concept(ConceptReference)
    case wildcard
    case nested(ECLExpression)
    case stringValue(String)
    case integerValue(Int)
    case booleanValue(Bool)

    func accept<V: ECLVisitor>(_ visitor: V) -> V.Result {
        visitor.visitAttributeValue(self)
    }
}

// MARK: - Attribute Group

/// A group of attributes enclosed in braces.
///
/// Example: `{ 363698007 = << 39057004, 116676008 = << 55641003 }`
struct AttributeGroup: ECLNode {
    let attributes: [RefinementItem]

    func accept<V: ECLVisitor>(_ visitor: V) -> V.Result {
        visitor.visitAttributeGroup(self)
    }
}

// MARK: - Cardinality

/// Cardinality constraint on an attribute.
///
/// Example: `[1..3]`, `[0..*]`
struct Cardinality: ECLNode {
    let min: Int
    let max: Int? // nil means unbounded (*)

    func accept<V: ECLVisitor>(_ visitor: V) -> V.Result {
        visitor.visitCardinality(self)
    }

    var text: String {
        let maxStr = max.map { String($0) } ?? "*"
        return "[\(min)..\(maxStr)]"
    }
}

// MARK: - Filter

/// A filter constraint on an expression.
///
/// Example: `{{ term = "heart" }}`
struct Filter: ECLNode {
    let constraints: [FilterConstraint]

    func accept<V: ECLVisitor>(_ visitor: V) -> V.Result {
        visitor.visitFilter(self)
    }
}

/// A single filter constraint.
enum FilterConstraint: ECLNode {
    case term(TermFilter)
    case language(String)
    case type(String)
    case dialect(String)
    case active(Bool)
    case moduleId(String)

    func accept<V: ECLVisitor>(_ visitor: V) -> V.Result {
        visitor.visitFilterConstraint(self)
    }
}

/// Term filter with optional match type.
struct TermFilter: ECLNode {
    enum MatchType: String {
        case exact
        case match
        case wild
    }

    let matchType: MatchType
    let value: String

    func accept<V: ECLVisitor>(_ visitor: V) -> V.Result {
        visitor.visitTermFilter(self)
    }
}

// MARK: - Visitor Protocol

/// Visitor protocol for traversing ECL AST.
protocol ECLVisitor {
    associatedtype Result

    func visitExpression(_ node: ECLExpression) -> Result
    func visitCompound(_ node: CompoundExpression) -> Result
    func visitRefined(_ node: RefinedExpression) -> Result
    func visitSubExpression(_ node: SubExpression) -> Result
    func visitFocusConcept(_ node: FocusConcept) -> Result
    func visitConceptReference(_ node: ConceptReference) -> Result
    func visitRefinement(_ node: Refinement) -> Result
    func visitRefinementItem(_ node: RefinementItem) -> Result
    func visitAttribute(_ node: Attribute) -> Result
    func visitAttributeName(_ node: AttributeName) -> Result
    func visitAttributeValue(_ node: AttributeValue) -> Result
    func visitAttributeGroup(_ node: AttributeGroup) -> Result
    func visitCardinality(_ node: Cardinality) -> Result
    func visitFilter(_ node: Filter) -> Result
    func visitFilterConstraint(_ node: FilterConstraint) -> Result
    func visitTermFilter(_ node: TermFilter) -> Result
}
