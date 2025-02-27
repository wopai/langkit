------------------------------------------------------------------------------
--                                                                          --
--                                 Langkit                                  --
--                                                                          --
--                     Copyright (C) 2014-2022, AdaCore                     --
--                                                                          --
-- Langkit is free software; you can redistribute it and/or modify it under --
-- terms of the  GNU General Public License  as published by the Free Soft- --
-- ware Foundation;  either version 3,  or (at your option)  any later ver- --
-- sion.   This software  is distributed in the hope that it will be useful --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY  or  FITNESS  FOR A PARTICULAR PURPOSE.                         --
--                                                                          --
-- As a special  exception  under  Section 7  of  GPL  version 3,  you are  --
-- granted additional  permissions described in the  GCC  Runtime  Library  --
-- Exception, version 3.1, as published by the Free Software Foundation.    --
--                                                                          --
-- You should have received a copy of the GNU General Public License and a  --
-- copy of the GCC Runtime Library Exception along with this program;  see  --
-- the files COPYING3 and COPYING.RUNTIME respectively.  If not, see        --
-- <http://www.gnu.org/licenses/>.                                          --
------------------------------------------------------------------------------

with Ada.Strings; use Ada.Strings;
with Ada.Strings.Fixed;

with Langkit_Support.Text; use Langkit_Support.Text;

package Langkit_Support.Slocs is

   type Line_Number is mod 2 ** 32;
   type Column_Number is mod 2 ** 16;

   type Relative_Position is (Before, Inside, After);
   --  Where some source location is with respect to another/a source location
   --  range.

   type Source_Location is record
      Line   : Line_Number;
      Column : Column_Number;
   end record;

   type Source_Location_Range is record
      Start_Line, End_Line     : Line_Number;
      Start_Column, End_Column : Column_Number;
   end record;

   No_Source_Location       : constant Source_Location       := (0, 0);
   No_Source_Location_Range : constant Source_Location_Range := (0, 0, 0, 0);

   --------------------------
   -- Constructors/getters --
   --------------------------

   function Start_Sloc
     (Sloc_Range : Source_Location_Range) return Source_Location
   is ((Line => Sloc_Range.Start_Line, Column => Sloc_Range.Start_Column));

   function End_Sloc
     (Sloc_Range : Source_Location_Range) return Source_Location
   is ((Line => Sloc_Range.End_Line, Column => Sloc_Range.End_Column));

   function Make_Range
     (Start_Sloc, End_Sloc : Source_Location) return Source_Location_Range
   is ((Start_Line   => Start_Sloc.Line,
        End_Line     => End_Sloc.Line,
        Start_Column => Start_Sloc.Column,
        End_Column   => End_Sloc.Column));

   --------------------------
   -- Location comparisons --
   --------------------------

   function Compare
     (Reference, Compared : Source_Location) return Relative_Position
      with Pre => (Reference /= No_Source_Location
                   and then Compared /= No_Source_Location);
   --  Tell where Compared is with respect to Reference (before, inside = same
   --  sloc, after).

   function "<" (L, R : Source_Location) return Boolean is
     (Compare (L, R) = After);
   function "<=" (L, R : Source_Location) return Boolean is
     (Compare (L, R) in After | Inside);
   function ">" (L, R : Source_Location) return Boolean is
     (Compare (L, R) = Before);
   function ">=" (L, R : Source_Location) return Boolean is
     (Compare (L, R) in Before | Inside);

   function Compare
     (Sloc_Range : Source_Location_Range;
      Sloc       : Source_Location) return Relative_Position
     with Pre => (Sloc_Range /= No_Source_Location_Range
                  and then Sloc /= No_Source_Location);
   --  Tell where Sloc is with respect to Sloc_Range

   ------------------------
   -- String conversions --
   ------------------------

   --  All functions below assume that the textual representation of
   --  Source_Location values have the form "L:C" (L being the line number, C
   --  the column number) and Source_Location_Range have the form
   --  "L1:C1-L2:C2" (L1 and C1 are numbers for the start sloc, L2 and C2 are
   --  the numbers for the end sloc).

   function Image (Sloc : Source_Location) return String is
     (Ada.Strings.Fixed.Trim (Line_Number'Image (Sloc.Line), Left) & ':'
      & Ada.Strings.Fixed.Trim (Column_Number'Image (Sloc.Column), Left));

   function Image (Sloc_Range : Source_Location_Range) return String is
     (Image (Start_Sloc (Sloc_Range)) & '-'
      & Image (End_Sloc (Sloc_Range)));

   function Image (Sloc : Source_Location) return Text_Type
   is (To_Text (Image (Sloc)));

   function Image (Sloc_Range : Source_Location_Range) return Text_Type
   is (To_Text (Image (Sloc_Range)));

   function Value (T : Text_Type) return Source_Location;
   function Value (S : String) return Source_Location
   is (Value (To_Text (S)));

   function Value (T : Text_Type) return Source_Location_Range;
   function Value (S : String) return Source_Location_Range
   is (Value (To_Text (S)));

   ---------------------------------
   -- Sloc computations from text --
   ---------------------------------

   Default_Tab_Stop : constant Positive := 8;
   --  Value that will be used for the default tab stop if none is passed
   --  during the initialization of a ``Token_Data_Handler``.

   function Column_Count
     (Line     : Text_Type;
      Tab_Stop : Positive := Default_Tab_Stop) return Column_Number;
   --  Return the number of columns in ``Line``, according to the given
   --  ``Tab_Stop`` to expand horizontal tabulations.

end Langkit_Support.Slocs;
