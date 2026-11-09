with Ada.Text_IO; use Ada.Text_IO;
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Directories;
with Ada.Exceptions;

procedure Main is
   package Positions is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Positive);
   use type Positions.Vector;
   package File_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (Key_Type => String, Element_Type => Positions.Vector);
   use type File_Maps.Map;
   package Word_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (Key_Type => String, Element_Type => File_Maps.Map);

   protected Shared_Index is
      procedure Merge (Local : Word_Maps.Map);
      procedure Report_Error (Message : String);
      function Snapshot return Word_Maps.Map;
      function Errors return Unbounded_String;
   private
      Data : Word_Maps.Map;
      Error_Text : Unbounded_String;
   end Shared_Index;

   protected body Shared_Index is
      procedure Merge (Local : Word_Maps.Map) is
         Files : File_Maps.Map;
      begin
         for W in Local.Iterate loop
            if Data.Contains (Word_Maps.Key (W)) then
               Files := Data.Element (Word_Maps.Key (W));
            else
               Files.Clear;
            end if;
            for F in Word_Maps.Element (W).Iterate loop
               Files.Insert (File_Maps.Key (F), File_Maps.Element (F));
            end loop;
            Data.Include (Word_Maps.Key (W), Files);
         end loop;
      end Merge;
      procedure Report_Error (Message : String) is
      begin
         Append (Error_Text, Message & ASCII.LF);
      end Report_Error;
      function Snapshot return Word_Maps.Map is (Data);
      function Errors return Unbounded_String is (Error_Text);
   end Shared_Index;

   procedure Index_File (Name : String; Local : out Word_Maps.Map) is
      Input : File_Type;
      Word : Unbounded_String;
      Position : Natural := 0;
      procedure Save_Word is
         Files : File_Maps.Map;
         Occurrences : Positions.Vector;
      begin
         if Length (Word) = 0 then
            return;
         end if;
         Position := Position + 1;
         if Local.Contains (To_String (Word)) then
            Files := Local.Element (To_String (Word));
            Occurrences := Files.Element (Name);
         end if;
         Occurrences.Append (Position);
         Files.Include (Name, Occurrences);
         Local.Include (To_String (Word), Files);
         Word := Null_Unbounded_String;
      end Save_Word;
   begin
      Open (Input, In_File, Name);
      while not End_Of_File (Input) loop
         declare
            Line : constant String := Get_Line (Input);
         begin
            for C of Line loop
               if C in 'a' .. 'z' then
                  Append (Word, C);
               elsif C in 'A' .. 'Z' then
                  Append (Word, Character'Val
                    (Character'Pos (C) + Character'Pos ('a') - Character'Pos ('A')));
               else
                  Save_Word;
               end if;
            end loop;
            Save_Word;
         end;
      end loop;
      Close (Input);
   exception
      when others =>
         if Is_Open (Input) then
            Close (Input);
         end if;
         raise;
   end Index_File;

   task type Worker (Argument_Number : Positive);
   task body Worker is
      Local : Word_Maps.Map;
   begin
      Index_File (Argument (Argument_Number), Local);
      Shared_Index.Merge (Local);
   exception
      when E : others =>
         Shared_Index.Report_Error
           (Argument (Argument_Number) & ": " & Ada.Exceptions.Exception_Message (E));
   end Worker;

   procedure Write_Index (Name : String; Data : Word_Maps.Map) is
      Output : File_Type;
   begin
      Create (Output, Out_File, Name);
      for W in Data.Iterate loop
         Put_Line (Output, Word_Maps.Key (W));
         for F in Word_Maps.Element (W).Iterate loop
            Put (Output, "  " & File_Maps.Key (F) & ":");
            for P of File_Maps.Element (F) loop
               Put (Output, Positive'Image (P));
            end loop;
            New_Line (Output);
         end loop;
      end loop;
      Close (Output);
   exception
      when others =>
         if Is_Open (Output) then
            Close (Output);
         end if;
         raise;
   end Write_Index;
begin
   if Argument_Count < 2 then
      Put_Line (Standard_Error, "Usage: main OUTPUT INPUT [INPUT ...]");
      Set_Exit_Status (Failure);
      return;
   end if;
   -- Reject duplicate inputs and an output path that aliases an input.
   for I in 2 .. Argument_Count loop
      if Ada.Directories.Full_Name (Argument (1)) =
        Ada.Directories.Full_Name (Argument (I))
      then
         raise Constraint_Error with "Output must differ from input files";
      end if;
      for J in 2 .. I - 1 loop
         if Ada.Directories.Full_Name (Argument (I)) =
           Ada.Directories.Full_Name (Argument (J))
         then
            raise Constraint_Error with "Duplicate input file";
         end if;
      end loop;
   end loop;
   Put_Line ("Indexing files with" & Integer'Image (Argument_Count - 1) & " Ada tasks...");
   declare
      type Worker_Access is access Worker;
      Workers : array (2 .. Argument_Count) of Worker_Access;
   begin
      for I in Workers'Range loop
         Workers (I) := new Worker (I);
      end loop;
   end; -- The master waits for all tasks before taking the snapshot.
   if Length (Shared_Index.Errors) > 0 then
      Put_Line (Standard_Error, To_String (Shared_Index.Errors));
      Set_Exit_Status (Failure);
      return;
   end if;
   declare
      Result : constant Word_Maps.Map := Shared_Index.Snapshot;
   begin
      Write_Index (Argument (1), Result);
      Put_Line ("Unique words:" & Result.Length'Image);
      Put_Line ("Index saved to " & Argument (1));
   end;
exception
   when E : others =>
      Put_Line (Standard_Error, Ada.Exceptions.Exception_Message (E));
      Set_Exit_Status (Failure);
end Main;
