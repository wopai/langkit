<%def name="field_type(astnode)">
  {
      % for field in ocaml_api.get_parse_fields(astnode):
         <%
            precise_types = ocaml_api.get_field_type(field)
         %>
         % if len(precise_types) == 1:
    ${ocaml_api.field_name(field)}: ${ocaml_api.type_public_name(
                                         precise_types[0])}
            % if field.is_optional:
    option
            % endif
    Lazy.t;
         % else:
    ${ocaml_api.field_name(field)}: [
            % for tpe in precise_types:
      | ${ocaml_api.polymorphic_variant_name(tpe)}
          of ${ocaml_api.fields_name(tpe)}
            % endfor
    ]
            % if field.is_optional:
    option
            % endif
    Lazy.t;
         % endif
      % endfor
      % if astnode.is_list:
    list : ${ocaml_api.type_public_name(astnode.element_type)} list Lazy.t;
      % endif
    c_value : entity;
    context : analysis_context
  }
</%def>

<%def name="sig(astnode)">
   ## Keep direct subclass type information, at least as a comment.
   ## Do not print it, if it's redundant with the concrete_subclasses.
   <%
     subclasses_len = len(astnode.subclasses)
     concrete_len = len(astnode.concrete_subclasses)
   %>
   % if astnode.abstract and subclasses_len != concrete_len:
  (**
      % for subclass in astnode.subclasses:
    * ${ocaml_api.type_public_name(subclass)}
      % endfor
    *)
   % endif
  and ${ocaml_api.type_public_name(astnode)} = [
   % for subclass in astnode.concrete_subclasses:
    | ${ocaml_api.polymorphic_variant_name(subclass)}
        of ${ocaml_api.fields_name(subclass)}
   % endfor
  ]
   % if not astnode.abstract:
  and ${ocaml_api.fields_name(astnode)} = ${field_type(astnode)}
   % endif
</%def>

<%def name='struct(astnode)'>

   % if astnode.abstract:
  and ${ocaml_api.wrap_function_name(astnode)} context c_value =
    (* This is an abstract node, call the root wrap function and filter to get
     the desired type *)
    match ${ocaml_api.wrap_value('c_value', root_entity, "context")} with
      % for tpe in astnode.concrete_subclasses:
      | ${ocaml_api.polymorphic_variant_name(tpe)} _
      % endfor
      as e -> e
      | _ ->
          (* This should not happen if the types are correct *)
          assert false
   % else:

  and ${ocaml_api.wrap_function_name(astnode)} context c_value
   : ${ocaml_api.type_public_name(astnode)} =
      % for field in ocaml_api.get_parse_fields(astnode):
    let ${ocaml_api.field_name(field)} () =
      let field_c_value = make ${ocaml_api.c_type(field.public_type)} in
      let _ : int = CFunctions.${field.accessor_basename.lower}
        (addr c_value)
        (addr field_c_value)
      in
      let node =
         ${ocaml_api.wrap_value('field_c_value', field.public_type, 'context',
             check_for_null=field.is_optional)}
      in
         <%
            precise_types = ocaml_api.get_field_type(field)
         %>

         % if len(precise_types) == 1:
      node
         % else:
      match node with
            <% some_or_nothing = 'Some ' if field.is_optional else '' %>
            % for tpe in precise_types:
      | ${some_or_nothing}${ocaml_api.polymorphic_variant_name(tpe)} _
            %  endfor
      ${'| None ' if field.is_optional else ''}as e -> e
      | _ -> assert false
         % endif
    in
      % endfor
      % if astnode.is_list:
    let list () =
      let c_value_ptr =
        allocate_n ${ocaml_api.c_type(T.entity.array)} ~count:1
      in
      let _ : int =
        CFunctions.${c_api.get_name('node_children')}
          (addr c_value)
          (c_value_ptr)
      in
      let c_value = !@(!@(c_value_ptr)) in
      let length = getf c_value ${ocaml_api.struct_name(T.entity.array)}.n in
      let items = c_value @. ${ocaml_api.struct_name(T.entity.array)}.items in
      let f i =
        let fresh = allocate EntityStruct.c_type !@(items +@ i) in
        (* This can raise a SyntaxError, which is expected *)
        ${ocaml_api.wrap_value('(!@ fresh)', astnode.element_type.entity,
                               'context')}
      in
      let result = List.init length f in
      ${ocaml_api.struct_name(T.entity.array)}.dec_ref (!@ c_value_ptr);
      result
    in
      % endif
    if is_null (getf c_value ${ocaml_api.struct_name(root_entity)}.node) then
      raise (SyntaxError "null node")
    else
      ${ocaml_api.polymorphic_variant_name(astnode)} {
      % for field in ocaml_api.get_parse_fields(astnode):
        ${ocaml_api.field_name(field)}
          = Lazy.from_fun ${ocaml_api.field_name(field)} ;
      % endfor
      % if astnode.is_list:
        list = Lazy.from_fun list;
      % endif
        c_value = c_value;
        context = context
      }
   % endif
</%def>
