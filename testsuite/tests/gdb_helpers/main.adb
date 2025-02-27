with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;

with Libfoolang.Analysis; use Libfoolang.Analysis;

procedure Main is
   Mode : constant String := (if Argument_Count = 0 then "" else Argument (1));

   U : constant Analysis_Unit := Create_Context.Get_From_Buffer
     (Filename => "main.txt", Buffer => "example example example");
   N : constant Foo_Node := U.Root.Child (1);

   Dummy_Int : Integer;
begin
   if U.Has_Diagnostics then
      for D of U.Diagnostics loop
         Put_Line (U.Format_GNU_Diagnostic (D));
      end loop;
      raise Program_Error;
   end if;

   if Mode = "" then
      null;

   elsif Mode = "printers" then
      declare
         Dummy : Analysis_Unit;
      begin
         Dummy := N.P_Id_Unit (U);
         Dummy := N.P_Id_Unit (No_Analysis_Unit);
      end;

      declare
         Dummy : Foo_Node;
      begin
         Dummy := N.P_Id_Node (N);
         Dummy := N.P_Id_Node (No_Foo_Node);
      end;

      Dummy_Int := N.P_Test_Strings;
      Dummy_Int := N.P_Test_Rebindings;
      Dummy_Int := N.P_Test_Envs;
      Dummy_Int := N.P_Test_Entities;
      Dummy_Int := N.P_Test_Arrays;
      Dummy_Int := N.P_Test_Vectors;
      Dummy_Int := N.P_Test_Tokens;

   elsif Mode = "control_flow" then
      Dummy_Int := N.P_Test_Control_Flow (1);
      Dummy_Int := N.P_Test_Control_Flow (2);
      Dummy_Int := N.P_Test_Control_Flow (3);

   else
      Put_Line ("Invalid mode argument");
   end if;
end Main;
