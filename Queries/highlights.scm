(line_comment) @comment

[
  (container_doc_comment)
  (doc_comment)
] @comment.doctag


[
  variable: (IDENTIFIER)
  variable_type_function: (IDENTIFIER)
] @variable

parameter: (IDENTIFIER) @identifier.argument

[
  field_member: (IDENTIFIER)
  field_access: (IDENTIFIER)
] @identifier.property

;; assume TitleCase is a type
(
  [
    variable_type_function: (IDENTIFIER)
    field_access: (IDENTIFIER)
    parameter: (IDENTIFIER)
    (BUILTINIDENTIFIER)
  ] @identifier.type
  (#match? @identifier.type "^@?[A-Z]([a-z]+[A-Za-z0-9]*)*$")
)
;; assume camelCase is a function
(
  [
    variable_type_function: (IDENTIFIER)
    field_access: (IDENTIFIER)
    parameter: (IDENTIFIER)
    (BUILTINIDENTIFIER)
  ] @identifier.function
  (#match? @identifier.function "^@?[a-z]+([A-Z][a-z0-9]*)+$")
)

;; assume all CAPS_1 is a constant
(
  [
    variable_type_function: (IDENTIFIER)
    field_access: (IDENTIFIER)
  ] @identifier.constant
  (#match? @identifier.constant "^[A-Z][A-Z_0-9]+$")
)

[
  function_call: (IDENTIFIER)
  function: (IDENTIFIER)
] @identifier.function

exception: "!" @operator

(
  (IDENTIFIER) @identifier.core
  (#eq? @identifier.core "_")
)

(PtrTypeStart "c" @identifier.core)

(
  (ContainerDeclType
    [
      (ErrorUnionExpr)
      "enum"
    ]
  )
  (ContainerField (IDENTIFIER) @identifier.key)
)

field_constant: (IDENTIFIER) @identifier.constant

(BUILTINIDENTIFIER) @identifier.core

((BUILTINIDENTIFIER) @processing
  (#match? @processing "^@(import|cImport)$"))

(INTEGER) @value.number

(FLOAT) @value.number

[
  (LINESTRING)
  (STRINGLITERALSINGLE)
] @string

(CHAR_LITERAL) @string
(EscapeSequence) @value.entity
(FormatSequence) @string-template.value

[
  "allowzero"
  "volatile"
] @keyword.modifier

[
  "anytype"
  "anyframe"
  (BuildinTypeExpr)
] @identifier.type @identifier.core

(BreakLabel (IDENTIFIER) @processing)
(BlockLabel (IDENTIFIER) @processing)

[
  "true"
  "false"
] @value.boolean

[
  "undefined"
  "unreachable"
  "null"
] @value.null

[
  "catch"
  "else"
  "for"
  "if"
  "switch"
  "try"
  "while"
] @keyword.condition

[
  "or"
  "and"
  "orelse"
] @keyword.operator

[
  "asm"
  "enum"
  "error"
  "fn"
  "opaque"
  "packed"
  "struct"
  "test"
  "union"
] @keyword.construct

[
  "align"
  "async"
  "callconv"
  "comptime"
  "const"
  "export"
  "extern"
  "inline"
  "linksection"
  "noalias"
  "noinline"
  "nosuspend"
  "pub"
  "threadlocal"
  "var"
] @keyword.modifier

"usingnamespace" @processing

[
  "return"
  "break"
  "continue"
] @keyword

; Macro
[
  "defer"
  "errdefer"
  "await"
  "suspend"
  "resume"
] @processing

[
  (CompareOp)
  (BitwiseOp)
  (BitShiftOp)
  (AdditionOp)
  (AssignOp)
  (MultiplyOp)
  (PrefixOp)
  "*"
  "**"
  "->"
  ".?"
  ".*"
  "?"
  ".."
] @operator

[
  ";"
  "."
  ","
  ":"
] @punctuation.delimiter

[
  "..."
] @punctuation.special

[
  "["
  "]"
  "("
  ")"
  "{"
  "}"
  (Payload "|")
  (PtrPayload "|")
  (PtrIndexPayload "|")
] @bracket

; Error
(ERROR) @invalid
