## vim: filetype=makoada

## If the current token denotes the end of the token stream, there is nothing
## to skip to: just make this parser fail.
if Get_Token (Parser.TDH.all, ${parser.start_pos}).Kind
   = From_Token_Kind (${ctx.lexer.Termination.ada_name})
then
   ${parser.pos_var} := No_Token_Index;
   goto ${exit_label};
end if;

## If a DontSkip ``other_parser`` parser up in the parsing call stack can parse
## what is next, abort the skip ad just make this parser fail.
for Fn of Parser.Private_Part.Dont_Skip loop
   ${parser.dummy_node} := Fn (Parser, ${parser.start_pos});

   if Parser.Current_Pos /= No_Token_Index  then
      ${parser.pos_var} := No_Token_Index;
      goto ${exit_label};
   end if;
end loop;

## Perform the skip: skip one token, create the result node and add an error
## message.
${parser.pos_var} := ${parser.start_pos} + 1;
${parser.dest_node_parser.generate_code()}
${parser.dest_node_parser.res_var}.Token_End_Index := ${parser.start_pos};

Append (Parser.Diagnostics,
        Sloc_Range (Parser.TDH.all,
                    Get_Token (Parser.TDH.all, ${parser.start_pos})),
        To_Text ("Skipped token ")
        & Common.Text
            (Wrap_Token_Reference
               (Parser.Unit.Context,
                Parser.TDH,
                (${parser.start_pos}, No_Token_Index))));

<<${exit_label}>>
