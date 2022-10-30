(
  (doc_comment)* @doc
  .
  (TopLevelDecl
    (FnProto
      function: (IDENTIFIER) @name
      (ParamDeclList) @arguments.target
    )
  ) @subtree @_method
  (#strip! @doc "^[\\s/]+")
  (#select-adjacent! @doc @_method)
  (#set! role function)
  (#set! arguments.query "arguments.scm")
)

(
  (doc_comment)* @doc
  .
  (TopLevelDecl
    (VarDecl
      variable_type_function: (IDENTIFIER) @name
      (ErrorUnionExpr
        (SuffixExpr
          (ContainerDecl
            (ContainerDeclType
              [ "struct" "enum" "union" ] @kind
            )
          )
        )
      )
    )
  ) @subtree @_container
  (#strip! @doc "^[\\s/]+")
  (#select-adjacent! @doc @_container)
  (#set-by-case-eq! @kind role
    "struct" struct
    "union" union
    "enum" enum
  )
)