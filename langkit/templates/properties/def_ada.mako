## vim: filetype=makoada

<%namespace name="scopes"  file="scopes_ada.mako" />
<%namespace name="helpers" file="helpers.mako" />

## Regular property function

<% has_logging = ctx.properties_logging and property.activate_tracing %>


% if property.abstract_runtime_check:

${"overriding" if property.overriding else ""} function ${property.name}
  ${helpers.argument_list(property, property.dispatching)}
   return ${property.type.name}
is (raise Property_Error
    with "Property ${property.qualname} not implemented on type "
    & Kind_Name (${property.self_arg_name}));

% elif not property.external and not property.abstract:
${gdb_property_start(property)}
pragma Warnings (Off, "is not referenced");
${"overriding" if property.overriding else ""} function ${property.name}
  ${helpers.argument_list(property, property.dispatching)}
   return ${property.type.name}
is
   ## We declare a variable Self, that has the named class wide access type
   ## that we can use to dispatch on other properties and all.
   Self : ${Self.type.name} := ${Self.type.name} (${property.self_arg_name});

   Call_Depth : aliased Natural;

   ## Dispatchers must not memoize because it will be done at the static
   ## property level: we do not want to do it twice.
   <% memoized = property.memoized and not property.is_dispatcher %>

   % if property._has_self_entity:
   Ent : ${Self.type.entity.name} :=
     ${Self.type.entity.name}'(Node => Self, Info => E_Info);
   ${gdb_bind('entity', 'Ent')}
   % else:
   ${gdb_bind('self', 'Self')}
   % endif

   % for arg in property.arguments:
   ${gdb_bind(arg.name.lower, arg.name.camel_with_underscores)}
   % endfor

   Property_Result : ${property.type.name};

   % if not property.is_dispatcher:
      ## For each scope, there is one of the following subprograms that
      ## finalizes all the ref-counted local variables it contains, excluding
      ## variables from children scopes.
      <% all_scopes = property.vars.all_scopes %>
      % for scope in all_scopes:
         % if scope.has_refcounted_vars():
            procedure ${scope.finalizer_name} with Inline_Always;
         % endif
      % endfor

      ${property.vars.render()}

      % for scope in all_scopes:
         % if scope.has_refcounted_vars():
            procedure ${scope.finalizer_name} is
            begin
               ## Finalize the local variable for this scope
               % for var in scope.variables:
                  % if var.type.is_refcounted:
                     Dec_Ref (${var.name});
                  % endif
               % endfor
            end ${scope.finalizer_name};
         % endif
      % endfor
   % endif

   % if memoized:
      <%
         key_length = 1 + len(property.arguments)
         if property.uses_entity_info:
            key_length += 1
      %>
      Mmz_Handle : Memoization_Handle;
      Mmz_Val    : Mmz_Value;

      Mmz_Stored : Boolean;
      --  Whether the memoization couple was actually stored. Used to determine
      --  whether to inc-ref the memoized value.

      function Create_Mmz_Key return Mmz_Key;
      --  Create a memoization key for this property call and return it

      --------------------
      -- Create_Mmz_Key --
      --------------------

      function Create_Mmz_Key return Mmz_Key is
      begin
         return Mmz_K : Mmz_Key :=
           (Property => ${property.memoization_enum},
            Items    => new Mmz_Key_Array (1 ..  ${key_length}))
         do
            Mmz_K.Items (1) := (Kind => ${property.struct.memoization_kind},
                                As_${property.struct.name} => Self);
            % for i, arg in enumerate(property.arguments, 2):
               Mmz_K.Items (${i}) := (Kind => ${arg.type.memoization_kind},
                                      As_${arg.type.name} => ${arg.name});
               % if arg.type.is_refcounted:
                  Inc_Ref (Mmz_K.Items (${i}).As_${arg.type.name});
               % endif
            % endfor
            % if property.uses_entity_info:
               Mmz_K.Items (${key_length}) :=
                 (Kind => ${T.entity_info.memoization_kind},
                  As_${T.entity_info.name} => ${property.entity_info_name});
            % endif
         end return;
      end Create_Mmz_Key;
   % endif

begin
   ${gdb_property_body_start()}

   ## If this is a lazy field, return it when it has already been evaluated
   ## once.
   % if property.lazy_field:
      if Self.${property.lazy_present_field.name} then
         Property_Result := Self.${property.lazy_storage_field.name};
         % if property.type.is_refcounted:
            Inc_Ref (Property_Result);
         % endif
         return Property_Result;
      end if;
   % endif

   ## Because they can be used this way in equation solving, properties must
   ## not crash when called on a null node.
   if Self /= null then
      Enter_Call (Self.Unit.Context, Call_Depth'Access);
   end if;

   % if has_logging:
      Properties_Traces.Trace
        ("${property.qualname} ("
        % if property._has_self_entity:
         & Trace_Image (Ent)
         % else:
         & Trace_Image (Self)
         % endif
         % for arg in property.arguments:
            & ", " & Trace_Image (${arg.name})
         % endfor
         & "):");
      Properties_Traces.Increase_Indent;
   % endif

   ## If this property uses env, we want to make sure lexical env caches are up
   ## to date.
   % if property.uses_envs:
      if Self /= null then
         Reset_Caches (Self.Unit);

         ## And if it is also public, we need to ensure that lexical
         ## environments are populated before executing the property itself.
         % if property.is_public:
            Populate_Lexical_Env (Self.Unit);
         % endif
      end if;
   % endif

   % if memoized:
      if Self = null then
         raise Property_Error with "property called on null node";
      end if;

      ## If memoization is enabled for this property, look for an already
      ## computed result for this property. See the declaration of
      ## Analysis_Context_Type.In_Populate_Lexical_Env for the rationale about
      ## the test that follows.

      % if not property.memoize_in_populate:
      if not Self.Unit.Context.In_Populate_Lexical_Env then
      % endif

         if Find_Memoized_Value
           (Self.Unit, Mmz_Handle, Mmz_Val, Create_Mmz_Key'Access)
         then
            ${gdb_memoization_lookup()}

            if Mmz_Val.Kind = Mmz_Evaluating then
               % if has_logging:
                  Properties_Traces.Trace
                    ("Result: infinite recursion");
               % endif
               ${gdb_memoization_return()}
               raise Property_Error with "Infinite recursion detected";

            elsif Mmz_Val.Kind = Mmz_Property_Error then
               % if has_logging:
                  Properties_Traces.Trace
                    ("Result: Property_Error");
                  Properties_Traces.Decrease_Indent;
               % endif
               ${gdb_memoization_return()}
               raise Property_Error with "Memoized error";

            else
               Property_Result := Mmz_Val.As_${property.type.name};
               % if property.type.is_refcounted:
                  Inc_Ref (Property_Result);
               % endif

               % if has_logging:
                  Properties_Traces.Trace
                    ("Result: " & Trace_Image (Property_Result));
                  Properties_Traces.Decrease_Indent;
               % endif
               ${gdb_memoization_return()}
               Exit_Call (Self.Unit.Context, Call_Depth);
               return Property_Result;
            end if;
            ${gdb_end()}
         end if;

      % if not property.memoize_in_populate:
      end if;
      % endif
   % endif

   % if property.is_dispatcher:
      if Self = null then
         raise Property_Error with "dispatching on null node";
      end if;

      ## If this property is a dispatcher, it has no expression: just
      ## materialize the dispatch table by hand.
      case ${property.struct.ada_kind_range_name} (Self.Kind) is
         % for types, static_prop in property.dispatch_table:
            % if types:
               when ${ctx.astnode_kind_set(types)} =>
                  ${gdb_property_call_start(static_prop)}
                  Property_Result := ${static_prop.name}
                    (Self
                     % for arg in property.arguments:
                        , ${arg.name}
                     % endfor
                     % if property.uses_entity_info:
                        , ${property.entity_info_name}
                     % endif
                    );
                  ${gdb_end()}
            % endif
         % endfor
      end case;

   % else:
      ${scopes.start_scope(property.vars.root_scope)}
      ${property.constructed_expr.render_pre()}

      Property_Result := ${property.constructed_expr.render_expr()};
      % if property.type.is_refcounted:
         Inc_Ref (Property_Result);
      % endif
      ${scopes.finalize_scope(property.vars.root_scope)}
   % endif

   % if memoized:
      ## If memoization is enabled for this property, save the result for later
      ## re-use. Note that memoization in during PLE is disabled unless
      ## specifically allowed for this property.
      % if not property.memoize_in_populate:
      if not Self.Unit.Context.In_Populate_Lexical_Env then
      % endif

         Mmz_Val := (Kind => ${property.type.memoization_kind},
                     As_${property.type.name} => Property_Result);
         Add_Memoized_Value (Self.Unit, Mmz_Handle, Mmz_Val, Mmz_Stored);
         % if property.type.is_refcounted:
            if Mmz_Stored then
               Inc_Ref (Property_Result);
            end if;
         % endif

      % if not property.memoize_in_populate:
      end if;
      % endif

   % elif property.lazy_field:
      ## If this property is the initializer for a lazy field, track its result
      ## in Self.
      Self.${property.lazy_present_field.name} := True;
      Self.${property.lazy_storage_field.name} := Property_Result;
      % if property.type.is_refcounted:
         Inc_Ref (Property_Result);
      % endif
   % endif

   % if has_logging:
      Properties_Traces.Trace
        ("Result: " & Trace_Image (Property_Result));
      Properties_Traces.Decrease_Indent;
   % endif

   if Self /= null then
      Exit_Call (Self.Unit.Context, Call_Depth);
   end if;
   return Property_Result;

exception

## Install an exception handler for Property_Error only if we have specific
## actions to do in this case.
% if (not property.is_dispatcher and \
          property.vars.root_scope.has_refcounted_vars(True)) or \
     memoized or \
     has_logging:
   when Property_Error =>
      % if not property.is_dispatcher:
         % for scope in all_scopes:
            % if scope.has_refcounted_vars():
               ${scope.finalizer_name};
            % endif
         % endfor
      % endif

      % if memoized:
         if Self /= null then
            % if not property.memoize_in_populate:
            if not Self.Unit.Context.In_Populate_Lexical_Env then
            % endif

               Add_Memoized_Value
                 (Self.Unit,
                  Mmz_Handle,
                  (Kind => Mmz_Property_Error),
                  Mmz_Stored);

            % if not property.memoize_in_populate:
            end if;
            % endif
         end if;
      % endif

      % if has_logging:
         Properties_Traces.Trace ("Result: Properties_Error");
         Properties_Traces.Decrease_Indent;
      % endif

      if Self /= null then
         Exit_Call (Self.Unit.Context, Call_Depth);
      end if;
      raise;
% endif

   when others =>
      if Self /= null then
         Exit_Call (Self.Unit.Context, Call_Depth);
      end if;
      raise;

end ${property.name};
${gdb_end()}
% endif
